defmodule WraftDocWeb.AdminNext.TemplateAssetImportLive do
  @moduledoc """
  Standalone LiveView for importing a new template asset (ZIP + optional thumbnail).

  Backpex's resource form doesn't currently host `Backpex.Fields.Upload` cleanly
  for this multi-step pipeline, so this page replicates the upload UX from the
  original Kaffy `WraftDocWeb.TemplateAssets.TemplateAssetAdmin.insert/2`:
  ZIP validation → file validation → `TemplateAssets.process_template_asset` →
  `Ecto.Multi` (Asset + TemplateAsset).

  Linked from the sidebar entry "Import Template Asset" and from a button on
  the `/admin/template-assets` page footer.
  """
  use Phoenix.LiveView

  alias Ecto.Multi
  alias WraftDoc.Assets
  alias WraftDoc.Assets.Asset
  alias WraftDoc.Repo
  alias WraftDoc.TemplateAssets
  alias WraftDoc.TemplateAssets.TemplateAsset
  alias WraftDoc.Utils.FileValidator

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Import Template Asset")
     |> assign(:fluid?, false)
     |> assign(:name, "")
     |> assign(:description, "")
     |> assign(:errors, [])
     |> allow_upload(:file,
       accept: ~w(.zip),
       max_entries: 1,
       max_file_size: 200_000_000
     )
     |> allow_upload(:thumbnail,
       accept: ~w(.png .jpg .jpeg .webp),
       max_entries: 1,
       max_file_size: 10_000_000
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <WraftDocWeb.AdminNext.Layouts.app {assigns}>
      <div class="card bg-base-100 shadow-sm">
        <div class="card-body space-y-6">
          <header class="space-y-1">
            <h1 class="text-2xl font-semibold">Import Template Asset</h1>
            <p class="text-base-content/60 text-sm">
              Upload a wraft template ZIP and an optional thumbnail. The ZIP is validated and unpacked into the Asset + TemplateAsset rows.
            </p>
          </header>

          <%= if @errors != [] do %>
            <div class="alert alert-error">
              <div>
                <h3 class="font-bold">Import failed</h3>
                <ul class="ml-4 list-disc text-sm">
                  <li :for={err <- @errors}>{err}</li>
                </ul>
              </div>
            </div>
          <% end %>

          <form
            phx-submit="import"
            phx-change="validate"
            class="space-y-4"
          >
            <fieldset class="fieldset">
              <legend class="fieldset-legend">Name</legend>
              <input
                type="text"
                name="name"
                value={@name}
                class="input input-bordered w-full"
                required
              />
            </fieldset>

            <fieldset class="fieldset">
              <legend class="fieldset-legend">Description</legend>
              <textarea
                name="description"
                rows="3"
                class="textarea textarea-bordered w-full"
              >{@description}</textarea>
            </fieldset>

            <fieldset class="fieldset">
              <legend class="fieldset-legend">Template ZIP (.zip)</legend>
              <.live_file_input upload={@uploads.file} class="file-input file-input-bordered w-full" />
              <div :for={entry <- @uploads.file.entries} class="mt-2 flex items-center gap-2 text-sm">
                <span class="font-mono">{entry.client_name}</span>
                <progress max="100" value={entry.progress} class="progress w-32" />
                <button
                  type="button"
                  phx-click="cancel-upload"
                  phx-value-ref={entry.ref}
                  phx-value-upload="file"
                  class="btn btn-ghost btn-xs"
                >
                  Cancel
                </button>
              </div>
              <p :for={err <- upload_errors(@uploads.file)} class="text-error text-xs">
                {error_to_string(err)}
              </p>
            </fieldset>

            <fieldset class="fieldset">
              <legend class="fieldset-legend">Thumbnail (optional)</legend>
              <.live_file_input
                upload={@uploads.thumbnail}
                class="file-input file-input-bordered w-full"
              />
              <div
                :for={entry <- @uploads.thumbnail.entries}
                class="mt-2 flex items-center gap-2 text-sm"
              >
                <span class="font-mono">{entry.client_name}</span>
                <progress max="100" value={entry.progress} class="progress w-32" />
                <button
                  type="button"
                  phx-click="cancel-upload"
                  phx-value-ref={entry.ref}
                  phx-value-upload="thumbnail"
                  class="btn btn-ghost btn-xs"
                >
                  Cancel
                </button>
              </div>
              <p :for={err <- upload_errors(@uploads.thumbnail)} class="text-error text-xs">
                {error_to_string(err)}
              </p>
            </fieldset>

            <div class="flex justify-end gap-2 pt-2">
              <.link navigate="/admin/template-assets" class="btn btn-ghost">Cancel</.link>
              <button type="submit" class="btn btn-primary">Import</button>
            </div>
          </form>
        </div>
      </div>
    </WraftDocWeb.AdminNext.Layouts.app>
    """
  end

  @impl true
  def handle_event("validate", params, socket) do
    {:noreply,
     socket
     |> assign(:name, Map.get(params, "name", ""))
     |> assign(:description, Map.get(params, "description", ""))
     |> assign(:errors, [])}
  end

  def handle_event("cancel-upload", %{"ref" => ref, "upload" => upload}, socket) do
    {:noreply, cancel_upload(socket, String.to_existing_atom(upload), ref)}
  end

  def handle_event("import", params, socket) do
    name = params |> Map.get("name", "") |> String.trim()
    description = Map.get(params, "description", "")

    with :ok <- require_present("Name", name),
         {:ok, file_upload} <- consume_required(socket, :file),
         {:ok, _} <- FileValidator.validate_file(file_upload.path),
         :ok <- TemplateAssets.validate_template_asset_file(file_upload),
         {:ok, thumbnail_upload} <- consume_optional(socket, :thumbnail),
         {:ok, base_params} <-
           build_params(name, description, file_upload, thumbnail_upload),
         {:ok, processed_params, _} <-
           TemplateAssets.process_template_asset(base_params, :file, file_upload),
         {:ok, %TemplateAsset{}} <- insert_multi(processed_params, file_upload.filename) do
      {:noreply,
       socket
       |> put_flash(:info, "Imported template asset \"#{name}\".")
       |> push_navigate(to: "/admin/template-assets")}
    else
      {:error, errors} when is_list(errors) ->
        msgs = Enum.map(errors, fn %{message: m, type: t} -> "#{t}: #{m}" end)
        {:noreply, assign(socket, :errors, msgs)}

      {:error, %Ecto.Changeset{} = cs} ->
        msgs = format_changeset(cs)
        {:noreply, assign(socket, :errors, msgs)}

      {:error, reason} when is_binary(reason) ->
        {:noreply, assign(socket, :errors, [reason])}

      {:error, reason} ->
        {:noreply, assign(socket, :errors, [inspect(reason)])}
    end
  end

  defp require_present(label, ""), do: {:error, "#{label} is required."}
  defp require_present(_label, _value), do: :ok

  defp consume_required(socket, upload_name) do
    case consume_uploaded_entries(socket, upload_name, fn meta, entry ->
           dest = persist_to_temp(meta.path, entry.client_name)

           {:ok,
            %Plug.Upload{path: dest, filename: entry.client_name, content_type: entry.client_type}}
         end) do
      [%Plug.Upload{} = upload] -> {:ok, upload}
      [] -> {:error, "Please attach a #{upload_name} file."}
    end
  end

  defp consume_optional(socket, upload_name) do
    case consume_uploaded_entries(socket, upload_name, fn meta, entry ->
           dest = persist_to_temp(meta.path, entry.client_name)

           {:ok,
            %Plug.Upload{path: dest, filename: entry.client_name, content_type: entry.client_type}}
         end) do
      [%Plug.Upload{} = upload] -> {:ok, upload}
      [] -> {:ok, nil}
    end
  end

  defp persist_to_temp(src_path, client_name) do
    dest =
      Path.join(System.tmp_dir!(), "wraft-#{System.unique_integer([:positive])}-#{client_name}")

    File.cp!(src_path, dest)
    dest
  end

  defp build_params(name, description, %Plug.Upload{} = file, thumbnail) do
    base = %{
      "name" => name,
      "description" => description,
      "file" => file,
      "type" => "zip"
    }

    base =
      case thumbnail do
        %Plug.Upload{} = t -> Map.put(base, "thumbnail", t)
        _ -> base
      end

    {:ok, base}
  end

  defp insert_multi(params, file_name) do
    Multi.new()
    |> Multi.run(:create_asset, fn _, _ ->
      Assets.create_asset(nil, params)
    end)
    |> Multi.run(:create_template_asset, fn _, %{create_asset: %Asset{id: asset_id}} ->
      TemplateAssets.create_template_asset(
        nil,
        Map.merge(params, %{"asset_id" => asset_id, "file_name" => file_name})
      )
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{create_template_asset: ta}} -> {:ok, ta}
      {:error, _, changeset, _} -> {:error, changeset}
    end
  end

  defp format_changeset(%Ecto.Changeset{errors: errors}) do
    Enum.map(errors, fn {field, {msg, _}} -> "#{Phoenix.Naming.humanize(field)} #{msg}" end)
  end

  defp error_to_string(:too_large), do: "File is too large."
  defp error_to_string(:not_accepted), do: "File type not accepted."
  defp error_to_string(:too_many_files), do: "Too many files."
  defp error_to_string(reason), do: inspect(reason)
end
