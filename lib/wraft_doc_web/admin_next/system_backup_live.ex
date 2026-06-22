defmodule WraftDocWeb.AdminNext.SystemBackupLive do
  @moduledoc """
  Admin LiveView for whole-application backups at `/admin/backups`.

  - per-row dropdown: Download (Database / Bucket / Full),
    Restore (here, or to another site), and Delete
  - a UI-configurable auto-backup schedule (enable + frequency + time)
  - manual import of an uploaded Full backup tar
  - restore into a NEW local DB+bucket, or to a remote site

  Downloads go through a CSRF POST that mints a single-use token; the rest
  are LiveView events. Refreshes by polling.
  """
  use Phoenix.LiveView

  import WraftDocWeb.AdminNext.UI

  alias WraftDoc.SystemBackups
  alias WraftDoc.SystemBackups.Archive
  alias WraftDocWeb.AdminNext.UI.Tokens

  @refresh_ms 10_000
  @max_upload 8_000_000_000

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: schedule_refresh()

    {:ok,
     socket
     |> assign(:page_title, "Backups")
     |> assign(:remote_modal, nil)
     |> assign(:remote_error, nil)
     |> allow_upload(:backup_file,
       accept: ~w(.zip .tar),
       max_entries: 1,
       max_file_size: @max_upload,
       auto_upload: true
     )
     |> load()}
  end

  @impl true
  def handle_event("take_backup", _params, socket) do
    {:noreply, socket |> flash_trigger() |> load()}
  end

  def handle_event("save_schedule", %{"schedule" => params}, socket) do
    socket =
      case SystemBackups.update_schedule(normalize_schedule(params)) do
        {:ok, _} -> put_flash(socket, :info, "Schedule saved.")
        {:error, _} -> put_flash(socket, :error, "Could not save the schedule. Check the values.")
      end

    {:noreply, load(socket)}
  end

  def handle_event("validate_import", _params, socket), do: {:noreply, socket}

  def handle_event("cancel_import", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :backup_file, ref)}
  end

  def handle_event("import_backup", _params, socket) do
    paths =
      consume_uploaded_entries(socket, :backup_file, fn %{path: tmp}, _entry ->
        stable =
          Path.join(System.tmp_dir!(), "wraft-import-#{System.unique_integer([:positive])}.tar")

        File.cp!(tmp, stable)
        {:ok, stable}
      end)

    socket =
      case paths do
        [stable] -> register_import(socket, stable)
        _ -> put_flash(socket, :error, "Choose a .zip (or .tar) backup file to import.")
      end

    {:noreply, load(socket)}
  end

  def handle_event("delete_backup", %{"id" => id}, socket) do
    socket =
      with %{status: :completed} = backup <- SystemBackups.get_backup(id),
           {:ok, _} <- SystemBackups.delete_backup(backup) do
        put_flash(socket, :info, "Backup deleted.")
      else
        {:error, _} -> put_flash(socket, :error, "Could not delete the backup.")
        _ -> put_flash(socket, :error, "Only completed backups can be deleted.")
      end

    {:noreply, load(socket)}
  end

  def handle_event("restore_backup", %{"id" => id}, socket) do
    socket =
      case SystemBackups.get_backup(id) do
        %{status: :completed} = backup -> do_local_restore(socket, backup)
        _ -> put_flash(socket, :error, "Only completed backups can be restored.")
      end

    {:noreply, load(socket)}
  end

  def handle_event("open_remote_restore", %{"id" => id}, socket) do
    {:noreply, assign(socket, remote_modal: id, remote_error: nil)}
  end

  def handle_event("close_remote_restore", _params, socket) do
    {:noreply, assign(socket, remote_modal: nil, remote_error: nil)}
  end

  def handle_event("submit_remote_restore", %{"remote" => remote}, socket) do
    backup = SystemBackups.get_backup(socket.assigns.remote_modal)

    case backup &&
           SystemBackups.start_remote_restore(
             socket.assigns.current_admin,
             backup,
             atomize(remote)
           ) do
      {:ok, _restore} ->
        {:noreply,
         socket
         |> assign(remote_modal: nil, remote_error: nil)
         |> put_flash(:info, "Remote restore started to #{remote["remote_s3_endpoint"]}.")
         |> load()}

      {:error, reason} ->
        {:noreply, assign(socket, remote_error: remote_error_message(reason))}

      _ ->
        {:noreply,
         assign(socket, remote_error: "Could not start the remote restore. Check the details.")}
    end
  end

  # Surface the actual validation reason (SSRF block, live-target refusal,
  # missing DB name, …) so the operator can correct the target.
  defp remote_error_message(:restore_in_progress), do: "A restore is already in progress."
  defp remote_error_message(:disabled), do: "The backup feature is disabled."

  defp remote_error_message(:remote_restore_disabled),
    do: "Remote restore is disabled on this server (BACKUP_REMOTE_RESTORE_ENABLED)."

  defp remote_error_message(reason) when is_binary(reason), do: reason
  defp remote_error_message(_), do: "Could not start the remote restore. Check the details."

  @impl true
  def handle_info(:refresh, socket) do
    schedule_refresh()
    {:noreply, load(socket)}
  end

  defp flash_trigger(socket) do
    case SystemBackups.trigger_manual(socket.assigns.current_admin) do
      {:ok, _} ->
        put_flash(socket, :info, "Backup started.")

      {:error, :disabled} ->
        put_flash(socket, :error, "The backup feature is disabled.")

      {:error, :backup_in_progress} ->
        put_flash(socket, :error, "A backup is already in progress.")

      {:error, :cooldown} ->
        put_flash(socket, :error, "Manual backups are limited to one per hour.")

      {:error, _} ->
        put_flash(socket, :error, "Could not start the backup.")
    end
  end

  defp do_local_restore(socket, backup) do
    case SystemBackups.start_restore(socket.assigns.current_admin, backup) do
      {:ok, restore} ->
        put_flash(
          socket,
          :info,
          "Restore started into #{restore.target_database} (live app untouched)."
        )

      {:error, :restore_in_progress} ->
        put_flash(socket, :error, "A restore is already in progress.")

      _ ->
        put_flash(socket, :error, "Could not start the restore.")
    end
  end

  # Only the known remote-restore fields, keyed as atoms — never call
  # String.to_existing_atom on arbitrary client-supplied keys.
  @remote_fields ~w(remote_database_url remote_s3_endpoint remote_s3_bucket
                    remote_s3_access_key_id remote_s3_secret)

  defp atomize(map) do
    Map.new(@remote_fields, fn field -> {String.to_atom(field), map[field]} end)
  end

  defp import_ready?(upload) do
    upload.entries != [] and Enum.all?(upload.entries, & &1.done?) and
      upload_errors(upload) == [] and
      Enum.all?(upload.entries, &(upload_errors(upload, &1) == []))
  end

  defp uploading?(upload), do: Enum.any?(upload.entries, &(not &1.done?))

  defp register_import(socket, stable) do
    # Validate the archive synchronously so a wrong/corrupt .tar gives
    # immediate feedback instead of a failed history row minutes later.
    case Archive.validate(stable) do
      :ok ->
        case SystemBackups.import_backup(socket.assigns.current_admin, stable) do
          {:ok, _backup} ->
            put_flash(socket, :info, "Import started — the uploaded backup is being registered.")

          {:error, :disabled} ->
            File.rm(stable)
            put_flash(socket, :error, "The backup feature is disabled.")

          {:error, _} ->
            File.rm(stable)
            put_flash(socket, :error, "Could not import the backup.")
        end

      {:error, message} ->
        File.rm(stable)
        put_flash(socket, :error, message)
    end
  end

  # The schedule form posts a single "HH:MM" time field; split it into
  # hour + minute for the changeset.
  defp normalize_schedule(%{"time" => time} = params) when is_binary(time) do
    case String.split(time, ":") do
      [h, m | _] -> params |> Map.put("hour", h) |> Map.put("minute", m) |> Map.delete("time")
      _ -> Map.delete(params, "time")
    end
  end

  defp normalize_schedule(params), do: params

  defp schedule_refresh, do: Process.send_after(self(), :refresh, @refresh_ms)

  defp load(socket) do
    backups = SystemBackups.list_backups()
    restores = SystemBackups.latest_restores_for(Enum.map(backups, & &1.id))

    rows = Enum.map(backups, fn b -> %{backup: b, restore: restores[b.id]} end)

    socket
    |> assign(:rows, rows)
    |> assign(:in_flight, SystemBackups.in_flight?())
    |> assign(:restore_in_flight, SystemBackups.restore_in_flight?())
    |> assign(:enabled, SystemBackups.enabled?())
    |> assign(:schedule, SystemBackups.get_schedule())
  end

  @impl true
  def render(assigns) do
    ~H"""
    <WraftDocWeb.AdminNext.Layouts.app {assigns}>
      <div class="space-y-6">
        <.page_header
          title="Backups"
          description="Back up your entire app, restore when needed, and automate backups on a schedule."
        >
          <:eyebrow>Security</:eyebrow>
          <:actions>
            <button class="btn btn-primary gap-2" phx-click="take_backup" disabled={@in_flight or not @enabled} phx-disable-with="Starting…">
              <span class="hero-archive-box-arrow-down size-4"></span> Take backup
            </button>
          </:actions>
        </.page_header>

        <.card :if={not @enabled} title="Feature disabled">
          <p class="text-sm text-base-content/70">
            System backups are off. Set <code>SYSTEM_BACKUP_ENABLED=true</code>
            and a <code>MINIO_BACKUP_BUCKET</code>.
          </p>
        </.card>

        <%!-- Schedule + import --%>
        <div class="grid gap-4 lg:grid-cols-2">
          <.card title="Automatic backups">
            <form phx-submit="save_schedule" class="text-sm">
              <label class="flex cursor-pointer items-start justify-between gap-4 pb-4">
                <span class="flex flex-col gap-0.5">
                  <span class="font-medium text-base-content">Run backups on a schedule</span>
                  <span class="text-xs text-base-content/55">{schedule_summary(@schedule)}</span>
                </span>
                <input type="hidden" name="schedule[enabled]" value="false" />
                <input
                  type="checkbox"
                  name="schedule[enabled]"
                  value="true"
                  checked={@schedule.enabled}
                  class="toggle toggle-primary toggle-sm mt-0.5"
                />
              </label>

              <div class="space-y-4 border-t border-base-200 pt-4">
                <div class="flex flex-wrap items-end gap-3">
                  <label class="flex flex-col gap-1.5">
                    <span class="text-xs font-medium text-base-content/55">Frequency</span>
                    <select name="schedule[frequency]" class="select select-bordered select-sm w-32">
                      <option value="daily" selected={@schedule.frequency == :daily}>Daily</option>
                      <option value="weekly" selected={@schedule.frequency == :weekly}>Weekly</option>
                    </select>
                  </label>
                  <label :if={@schedule.frequency == :weekly} class="flex flex-col gap-1.5">
                    <span class="text-xs font-medium text-base-content/55">Day</span>
                    <select name="schedule[day_of_week]" class="select select-bordered select-sm w-36">
                      <option :for={{label, n} <- weekdays()} value={n} selected={@schedule.day_of_week == n}>
                        {label}
                      </option>
                    </select>
                  </label>
                  <label class="flex flex-col gap-1.5">
                    <span class="text-xs font-medium text-base-content/55">Time (UTC)</span>
                    <input
                      type="time"
                      name="schedule[time]"
                      value={time_value(@schedule)}
                      class="input input-bordered input-sm w-32"
                    />
                  </label>
                </div>

                <div class="flex flex-wrap items-end gap-x-6 gap-y-3">
                  <label class="flex flex-col gap-1.5">
                    <span class="text-xs font-medium text-base-content/55">Keep last</span>
                    <span class="flex items-baseline gap-2">
                      <input
                        type="number"
                        name="schedule[retention_count]"
                        min="1"
                        max="365"
                        value={@schedule.retention_count}
                        class="input input-bordered input-sm w-16"
                      />
                      <span class="text-xs text-base-content/50">backups</span>
                    </span>
                  </label>
                  <label class="flex flex-col gap-1.5">
                    <span class="text-xs font-medium text-base-content/55">Min. gap between manual runs</span>
                    <span class="flex items-baseline gap-2">
                      <input
                        type="number"
                        name="schedule[manual_cooldown_minutes]"
                        min="0"
                        max="1440"
                        value={@schedule.manual_cooldown_minutes}
                        class="input input-bordered input-sm w-16"
                      />
                      <span class="text-xs text-base-content/50">min · 0 = no limit</span>
                    </span>
                  </label>
                </div>

                <button class="btn btn-outline btn-sm gap-2" type="submit">
                  <span class="hero-check size-4"></span> Save schedule
                </button>
              </div>
            </form>
          </.card>

          <.card title="Import a backup">
            <form
              phx-submit="import_backup"
              phx-change="validate_import"
              class="space-y-4 text-sm"
            >
              <p class="text-xs text-base-content/55">
                Upload a <span class="font-medium text-base-content/70">Full</span>
                backup archive (<code class="text-[11px]">.zip</code>) exported from another
                Wraft instance to register it here — then download or restore it like any backup.
              </p>
              <.live_file_input
                upload={@uploads.backup_file}
                class="file-input file-input-bordered file-input-sm w-full"
              />

              <div :for={entry <- @uploads.backup_file.entries} class="space-y-1.5">
                <div class="flex items-center justify-between gap-2 text-xs text-base-content/60">
                  <span class="truncate">{entry.client_name}</span>
                  <span class="flex items-center gap-2">
                    <span class="tabular-nums">{entry.progress}%</span>
                    <button
                      type="button"
                      class="text-base-content/40 hover:text-error"
                      phx-click="cancel_import"
                      phx-value-ref={entry.ref}
                      aria-label="Cancel upload"
                    >
                      <span class="hero-x-mark size-4"></span>
                    </button>
                  </span>
                </div>
                <progress
                  class="progress progress-primary h-1.5 w-full"
                  value={entry.progress}
                  max="100"
                >
                </progress>
                <p
                  :for={err <- upload_errors(@uploads.backup_file, entry)}
                  class="text-error text-xs"
                >
                  {error_text(err)}
                </p>
              </div>

              <p :for={err <- upload_errors(@uploads.backup_file)} class="text-error text-xs">
                {error_text(err)}
              </p>

              <button
                class="btn btn-outline btn-sm gap-2"
                type="submit"
                disabled={not @enabled or not import_ready?(@uploads.backup_file)}
              >
                <span class="hero-arrow-up-tray size-4"></span>
                {if uploading?(@uploads.backup_file), do: "Uploading…", else: "Import backup"}
              </button>
            </form>
          </.card>
        </div>

        <.card title="Backup history" caption={history_caption(@rows)}>
          <%= if @rows == [] do %>
            <.empty_state icon="hero-archive-box" title="No backups yet" description="Trigger one above, import one, or wait for the schedule." />
          <% else %>
            <.data_table>
              <:col label="Created" />
              <:col label="Trigger" />
              <:col label="Status" />
              <:col label="DB / Bucket" />
              <:col label="Restore" />
              <:col label="" align="right" />
              <:row>
                <tr :for={%{backup: backup, restore: restore} <- @rows} class="[&>td]:align-top">
                  <td class="text-xs text-base-content/70">
                    {Tokens.format_datetime(backup.inserted_at)}
                    <p class="text-[10px] text-base-content/50">{actor(backup)}</p>
                  </td>
                  <td><.badge variant={trigger_variant(backup.trigger_type)}>{backup.trigger_type}</.badge></td>
                  <td>
                    <.badge variant={status_variant(backup.status)}>{backup.status}</.badge>
                    <p :if={backup.status == :failed and backup.error} class="mt-1 max-w-xs truncate text-[10px] text-base-content/50" title={backup.error}>{backup.error}</p>
                  </td>
                  <td class="text-xs text-base-content/70">
                    <span :if={backup.status == :completed}>
                      {format_bytes(backup.db_size)} / {format_bytes(backup.bucket_size)}
                    </span>
                    <span :if={backup.status != :completed}>—</span>
                  </td>
                  <td class="text-xs">
                    <.badge :if={restore} variant={status_variant(restore.status)}>{restore.status}</.badge>
                    <p :if={restore} class="mt-1 text-[10px] text-base-content/50">{restore_target(restore)}</p>
                    <span :if={is_nil(restore)} class="text-base-content/40">—</span>
                  </td>
                  <td class="text-right">
                    <.actions_menu :if={backup.status == :completed} backup={backup} restore_in_flight={@restore_in_flight} />
                    <span :if={backup.status != :completed} class="text-base-content/40">—</span>
                  </td>
                </tr>
              </:row>
            </.data_table>
          <% end %>
        </.card>
      </div>

      <.remote_modal :if={@remote_modal} backup_id={@remote_modal} error={@remote_error} />
    </WraftDocWeb.AdminNext.Layouts.app>
    """
  end

  # Per-row dropdown: grouped Download + Restore + Delete.
  #
  # Uses the native Popover API + CSS anchor positioning so the menu
  # renders in the top layer and is NOT clipped by the table's
  # `overflow-x-auto` wrapper (an absolutely-positioned dropdown would be).
  defp actions_menu(assigns) do
    assigns = assign(assigns, :anchor, "actions-#{assigns.backup.id}")

    ~H"""
    <button
      class="btn btn-sm btn-outline gap-2"
      popovertarget={@anchor}
      style={"anchor-name:--#{@anchor}"}
    >
      <span class="hero-ellipsis-horizontal size-4"></span> Actions
    </button>
    <ul
      class="dropdown dropdown-end z-10 w-56 space-y-0.5 rounded-box bg-base-100 p-2 shadow-lg"
      popover
      id={@anchor}
      style={"position-anchor:--#{@anchor}"}
    >
      <li class={menu_title_class()}>Download</li>
      <li><.dl backup={@backup} part="db" label="Download Database" /></li>
      <li><.dl backup={@backup} part="bucket" label="Download Bucket" /></li>
      <li><.dl backup={@backup} part="full" label="Download Full" /></li>
      <li class={menu_title_class()}>Restore</li>
      <li>
        <button type="button" class={menu_item_class()} phx-click="restore_backup" phx-value-id={@backup.id} disabled={@restore_in_flight}
          data-confirm="Restore this backup into a NEW database + bucket here? The live app is not touched.">
          Restore Backup
        </button>
      </li>
      <li>
        <button type="button" class={menu_item_class()} phx-click="open_remote_restore" phx-value-id={@backup.id} disabled={@restore_in_flight}>
          Restore on another Site
        </button>
      </li>
      <li class="mt-1 border-t border-base-200 pt-1">
        <button type="button" class={[menu_item_class(), "text-error"]} phx-click="delete_backup" phx-value-id={@backup.id}
          data-confirm="Permanently delete this backup and its artifacts?">
          Delete
        </button>
      </li>
    </ul>
    """
  end

  # Shared so every row — download forms and restore/delete buttons — has
  # identical padding and alignment (daisyUI's `menu` auto-padding indents
  # form-wrapped rows differently from plain-button rows).
  defp menu_item_class,
    do:
      "block w-full rounded-lg px-3 py-1.5 text-left text-sm hover:bg-base-200 disabled:opacity-40 disabled:hover:bg-transparent"

  defp menu_title_class,
    do:
      "px-3 pb-0.5 pt-1.5 text-[10px] font-semibold uppercase tracking-wide text-base-content/40"

  # A download menu item: CSRF POST that mints a single-use token for a part.
  # `display: contents` on the form keeps the button as the styled row.
  defp dl(assigns) do
    ~H"""
    <form action={"/admin/backups/#{@backup.id}/authorize-download/#{@part}"} method="post" class="contents">
      <input type="hidden" name="_csrf_token" value={Phoenix.Controller.get_csrf_token()} />
      <button type="submit" class={menu_item_class()}>{@label}</button>
    </form>
    """
  end

  defp remote_modal(assigns) do
    ~H"""
    <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4" phx-click="close_remote_restore">
      <div class="w-full max-w-lg rounded-box bg-base-100 p-5 shadow-xl" phx-click-away="close_remote_restore" onclick="event.stopPropagation()">
        <h3 class="text-lg font-semibold">Restore on another site</h3>
        <p class="mt-1 text-xs text-base-content/60">
          Restores this backup into the target's database and bucket. <strong>Overwrites</strong> the target — point it at a fresh/empty instance.
        </p>
        <p :if={@error} class="mt-2 text-sm text-error">{@error}</p>
        <form phx-submit="submit_remote_restore" class="mt-4 space-y-3 text-sm">
          <label class="flex flex-col gap-1">
            <span class="text-xs text-base-content/60">Remote Postgres URL</span>
            <input name="remote[remote_database_url]" required placeholder="postgres://user:pass@host:5432/dbname" class="input input-bordered input-sm" />
          </label>
          <div class="grid grid-cols-2 gap-3">
            <label class="flex flex-col gap-1">
              <span class="text-xs text-base-content/60">S3 / MinIO endpoint</span>
              <input name="remote[remote_s3_endpoint]" required placeholder="https://minio.example.com" class="input input-bordered input-sm" />
            </label>
            <label class="flex flex-col gap-1">
              <span class="text-xs text-base-content/60">Bucket</span>
              <input name="remote[remote_s3_bucket]" required placeholder="wraft" class="input input-bordered input-sm" />
            </label>
            <label class="flex flex-col gap-1">
              <span class="text-xs text-base-content/60">Access key ID</span>
              <input name="remote[remote_s3_access_key_id]" required class="input input-bordered input-sm" />
            </label>
            <label class="flex flex-col gap-1">
              <span class="text-xs text-base-content/60">Secret key</span>
              <input name="remote[remote_s3_secret]" type="password" required class="input input-bordered input-sm" />
            </label>
          </div>
          <div class="flex justify-end gap-2 pt-1">
            <button class="btn btn-ghost btn-sm" type="button" phx-click="close_remote_restore">Cancel</button>
            <button class="btn btn-primary btn-sm gap-2" type="submit">
              <span class="hero-server size-4"></span> Start remote restore
            </button>
          </div>
        </form>
      </div>
    </div>
    """
  end

  defp actor(%{creator: %{email: email}}), do: email
  defp actor(_), do: "System"

  defp restore_target(%{target_type: :remote, remote_s3_endpoint: ep}), do: "remote: #{ep}"
  defp restore_target(%{target_database: db}), do: db

  # Trigger is a category label — keep it neutral so colour signals status,
  # not provenance. Imported gets a subtle highlight (data from elsewhere).
  defp trigger_variant(:imported), do: "warning"
  defp trigger_variant(_), do: "neutral"

  defp status_variant(:pending), do: "warning"
  defp status_variant(:running), do: "primary"
  defp status_variant(:completed), do: "success"
  defp status_variant(:failed), do: "error"
  defp status_variant(_), do: "neutral"

  defp history_caption(rows) do
    completed = Enum.count(rows, &(&1.backup.status == :completed))
    "#{length(rows)} recent backups · #{completed} downloadable"
  end

  defp weekdays,
    do: [
      {"Monday", 1},
      {"Tuesday", 2},
      {"Wednesday", 3},
      {"Thursday", 4},
      {"Friday", 5},
      {"Saturday", 6},
      {"Sunday", 7}
    ]

  defp time_value(s), do: to_string(:io_lib.format("~2..0B:~2..0B", [s.hour, s.minute]))

  defp schedule_summary(%{enabled: false}),
    do: "Off — backups run only when you trigger them."

  defp schedule_summary(%{frequency: :weekly} = s),
    do:
      "On — every #{weekday_name(s.day_of_week)} at #{time_value(s)} UTC, keeping #{s.retention_count}."

  defp schedule_summary(s),
    do: "On — daily at #{time_value(s)} UTC, keeping the last #{s.retention_count}."

  defp weekday_name(n) do
    {name, _} = Enum.find(weekdays(), {"Monday", 1}, fn {_, i} -> i == n end)
    name
  end

  defp error_text(:too_large), do: "File is too large."
  defp error_text(:not_accepted), do: "Only .zip or .tar files are accepted."
  defp error_text(other), do: "Upload error: #{inspect(other)}"

  defp format_bytes(nil), do: "—"
  defp format_bytes(b) when b >= 1_073_741_824, do: "#{Float.round(b / 1_073_741_824, 2)} GB"
  defp format_bytes(b) when b >= 1_048_576, do: "#{Float.round(b / 1_048_576, 1)} MB"
  defp format_bytes(b) when b >= 1_024, do: "#{Float.round(b / 1_024, 1)} KB"
  defp format_bytes(b), do: "#{b} B"
end
