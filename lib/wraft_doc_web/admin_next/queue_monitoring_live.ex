defmodule WraftDocWeb.AdminNext.QueueMonitoringLive do
  @moduledoc """
  Admin LiveView for Oban queue monitoring at `/admin/queue-monitoring`.

  Two views share this module:

  - `:index` — summary stat cards, per-queue breakdown table, recent
    failures card, and a filterable/paginated list of jobs.
  - `:show`  — detail view for a single job (state, attempts, args, meta,
    last error stacktrace) at `/admin/queue-monitoring/:id`.

  Strictly read-only. Operators that need to cancel / retry / delete jobs
  should use the full Oban Web dashboard at `/oban`.

  Auto-refreshes on `:index` every #{30}s so the page stays current
  without operator interaction. The refresh button forces an immediate
  reload (also used to reset `tick`'s drift).
  """
  use Phoenix.LiveView

  import WraftDocWeb.AdminNext.UI

  alias WraftDoc.Admin.QueueMonitoring
  alias WraftDocWeb.AdminNext.UI.Tokens

  @page_size 25
  @refresh_ms 30_000

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: schedule_refresh()

    {:ok,
     socket
     |> assign(:page_size, @page_size)
     |> assign(:page, 1)
     |> assign(:state_filter, "")
     |> assign(:queue_filter, "")
     |> assign(:worker_filter, "")
     |> assign(:result, empty_result())
     |> assign(:summary, %{total: 0})
     |> assign(:throughput, %{inserted: 0, failed: 0})
     |> assign(:queue_rows, [])
     |> assign(:recent_failures, [])
     |> assign(:queue_options, [])
     |> assign(:selected, nil)
     |> assign(:last_refreshed_at, DateTime.utc_now())}
  end

  @impl true
  def handle_params(params, _url, %{assigns: %{live_action: :show}} = socket) do
    {:noreply,
     socket
     |> assign(:page_title, "Job detail")
     |> assign(:selected, QueueMonitoring.get(params["id"]))}
  end

  def handle_params(_params, _url, socket) do
    {:noreply,
     socket
     |> assign(:page_title, "Queue Monitoring")
     |> assign(:selected, nil)
     |> load_all()}
  end

  # ---------------------------------------------------------------------------
  # Events
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("filter", params, socket) do
    {:noreply,
     socket
     |> assign(:state_filter, params["state"] || "")
     |> assign(:queue_filter, params["queue"] || "")
     |> assign(:worker_filter, params["worker"] || "")
     |> assign(:page, 1)
     |> load_jobs()}
  end

  def handle_event("clear_filters", _params, socket) do
    {:noreply,
     socket
     |> assign(:state_filter, "")
     |> assign(:queue_filter, "")
     |> assign(:worker_filter, "")
     |> assign(:page, 1)
     |> load_jobs()}
  end

  def handle_event("prev_page", _params, socket) do
    {:noreply, socket |> assign(:page, max(socket.assigns.page - 1, 1)) |> load_jobs()}
  end

  def handle_event("next_page", _params, socket) do
    %{page: page, result: %{page_count: page_count}} = socket.assigns
    {:noreply, socket |> assign(:page, min(page + 1, max(page_count, 1))) |> load_jobs()}
  end

  def handle_event("refresh", _params, socket) do
    {:noreply, load_all(socket)}
  end

  def handle_event("show_detail", %{"id" => id}, socket) do
    {:noreply, push_navigate(socket, to: "/admin/queue-monitoring/#{URI.encode(to_string(id))}")}
  end

  @impl true
  def handle_info(:refresh, socket) do
    schedule_refresh()

    case socket.assigns.live_action do
      :show -> {:noreply, assign(socket, :selected, QueueMonitoring.get(socket.assigns.selected && socket.assigns.selected.id))}
      _ -> {:noreply, load_all(socket)}
    end
  end

  defp schedule_refresh, do: Process.send_after(self(), :refresh, @refresh_ms)

  # ---------------------------------------------------------------------------
  # Data loading
  # ---------------------------------------------------------------------------

  defp load_all(socket) do
    socket
    |> assign(:summary, QueueMonitoring.state_counts())
    |> assign(:throughput, QueueMonitoring.throughput(24))
    |> assign(:queue_rows, QueueMonitoring.queue_breakdown())
    |> assign(:recent_failures, QueueMonitoring.recent_failures(5))
    |> assign(:queue_options, QueueMonitoring.queues())
    |> assign(:last_refreshed_at, DateTime.utc_now())
    |> load_jobs()
  end

  defp load_jobs(socket) do
    %{
      page: page,
      page_size: page_size,
      state_filter: state,
      queue_filter: queue,
      worker_filter: worker
    } = socket.assigns

    result =
      QueueMonitoring.list(
        page: page,
        page_size: page_size,
        state: state,
        queue: queue,
        worker: worker
      )

    assign(socket, :result, result)
  end

  defp empty_result do
    %{entries: [], page: 1, page_count: 1, page_size: @page_size, total: 0}
  end

  # ---------------------------------------------------------------------------
  # Render
  # ---------------------------------------------------------------------------

  @impl true
  def render(%{live_action: :show} = assigns), do: show_view(assigns)
  def render(assigns), do: index_view(assigns)

  defp index_view(assigns) do
    ~H"""
    <WraftDocWeb.AdminNext.Layouts.app {assigns}>
      <div class="space-y-6">
        <.page_header
          title="Queue Monitoring"
          description="Background-job health across every Oban queue. Counts read directly from the jobs table; completed jobs are pruned aggressively, so steady-state totals are dominated by scheduled and retryable work."
        >
          <:eyebrow>Automation & Integrations</:eyebrow>
          <:status>
            <.status_pill variant={overall_variant(@summary, @throughput)}>
              {overall_label(@summary, @throughput)}
            </.status_pill>
          </:status>
          <:actions>
            <.button variant="ghost" icon="hero-arrow-top-right-on-square" href="/oban">
              Oban dashboard
            </.button>
            <.button variant="neutral" icon="hero-arrow-path" phx-click="refresh">
              Refresh
            </.button>
          </:actions>
        </.page_header>

        <%!-- Summary cards by state --%>
        <section class="grid grid-cols-2 gap-4 sm:grid-cols-4 lg:grid-cols-4">
          <.mini_stat icon="hero-bolt" label="Executing" value={@summary["executing"] || 0} />
          <.mini_stat icon="hero-queue-list" label="Available" value={@summary["available"] || 0} />
          <.mini_stat icon="hero-clock" label="Scheduled" value={@summary["scheduled"] || 0} />
          <.mini_stat icon="hero-arrow-path" label="Retryable" value={@summary["retryable"] || 0} />
          <.mini_stat icon="hero-check-circle" label="Completed (recent)" value={@summary["completed"] || 0} />
          <.mini_stat icon="hero-x-circle" label="Discarded" value={@summary["discarded"] || 0} />
          <.mini_stat icon="hero-minus-circle" label="Cancelled" value={@summary["cancelled"] || 0} />
          <.mini_stat icon="hero-chart-bar" label="Inserted (24h)" value={@throughput.inserted} />
        </section>

        <%!-- Per-queue breakdown --%>
        <.card
          title="Queues"
          caption={queue_caption(@queue_rows, @last_refreshed_at)}
        >
          <%= if @queue_rows == [] do %>
            <.empty_state
              icon="hero-queue-list"
              title="No queues found"
              description="No Oban queues are configured or have ever processed a job. Check the application config under `config :wraft_doc, Oban`."
            />
          <% else %>
            <.data_table>
              <:col label="Queue" />
              <:col label="Limit" align="right" />
              <:col label="Executing" align="right" />
              <:col label="Available" align="right" />
              <:col label="Scheduled" align="right" />
              <:col label="Retryable" align="right" />
              <:col label="Discarded" align="right" />
              <:col label="Total" align="right" />
              <:col label="Producer" />
              <:row>
                <tr :for={row <- @queue_rows} class="align-top">
                  <td class="font-medium text-base-content">
                    <span class="font-mono text-xs">{row.queue}</span>
                  </td>
                  <td class="text-right tabular-nums text-base-content/70">
                    {row.limit || "—"}
                  </td>
                  <td class="text-right tabular-nums">
                    <.badge :if={row.states["executing"] > 0} variant="primary">
                      {row.states["executing"]}
                    </.badge>
                    <span :if={row.states["executing"] == 0} class="text-base-content/40">0</span>
                  </td>
                  <td class="text-right tabular-nums text-base-content">
                    {row.states["available"]}
                  </td>
                  <td class="text-right tabular-nums text-base-content/70">
                    {row.states["scheduled"]}
                  </td>
                  <td class="text-right tabular-nums">
                    <.badge :if={row.states["retryable"] > 0} variant="warning">
                      {row.states["retryable"]}
                    </.badge>
                    <span :if={row.states["retryable"] == 0} class="text-base-content/40">0</span>
                  </td>
                  <td class="text-right tabular-nums">
                    <.badge :if={row.states["discarded"] > 0} variant="error">
                      {row.states["discarded"]}
                    </.badge>
                    <span :if={row.states["discarded"] == 0} class="text-base-content/40">0</span>
                  </td>
                  <td class="text-right tabular-nums font-medium text-base-content">
                    {row.total}
                  </td>
                  <td>
                    {producer_badge(assigns_for_producer(row))}
                  </td>
                </tr>
              </:row>
            </.data_table>
          <% end %>
        </.card>

        <%!-- Recent failures --%>
        <.card
          title="Recent failures"
          caption="Jobs in discarded, cancelled, or retryable state — newest first. Click a row for the full stacktrace."
        >
          <%= if @recent_failures == [] do %>
            <.empty_state
              icon="hero-check-badge"
              title="No recent failures"
              description="Every recent job either completed or is still waiting. Nothing has been discarded or retried."
            />
          <% else %>
            <.data_table>
              <:col label="State" />
              <:col label="Worker" />
              <:col label="Queue" />
              <:col label="Attempts" align="right" />
              <:col label="Last error" />
              <:col label="When" align="right" />
              <:row>
                <tr
                  :for={job <- @recent_failures}
                  phx-click="show_detail"
                  phx-value-id={job.id}
                  class="cursor-pointer hover:bg-base-200/60 align-top"
                >
                  <td>
                    <.badge variant={state_variant(job.state)}>{job.state}</.badge>
                  </td>
                  <td class="font-mono text-xs text-base-content">{short_worker(job.worker)}</td>
                  <td class="font-mono text-xs text-base-content/70">{job.queue}</td>
                  <td class="text-right tabular-nums text-base-content/80">
                    {job.attempt}/{job.max_attempts}
                  </td>
                  <td class="max-w-[28rem] truncate font-mono text-xs text-error/90">
                    {last_error(job)}
                  </td>
                  <td class="text-right text-xs text-base-content/60">
                    {Tokens.format_datetime(job_event_time(job))}
                  </td>
                </tr>
              </:row>
            </.data_table>
          <% end %>
        </.card>

        <%!-- Recent jobs (filterable) --%>
        <.card
          title="Activity"
          caption={result_caption(@result)}
        >
          <:header_actions>
            <form
              phx-change="filter"
              phx-submit="filter"
              class="flex flex-wrap items-center gap-2"
            >
              <select name="state" class="select select-bordered select-sm">
                <option value="" selected={@state_filter == ""}>All states</option>
                <option
                  :for={s <- QueueMonitoring.states()}
                  value={s}
                  selected={@state_filter == s}
                >
                  {String.capitalize(s)}
                </option>
              </select>

              <select name="queue" class="select select-bordered select-sm">
                <option value="" selected={@queue_filter == ""}>All queues</option>
                <option
                  :for={q <- @queue_options}
                  value={q}
                  selected={@queue_filter == q}
                >
                  {q}
                </option>
              </select>

              <input
                type="search"
                name="worker"
                value={@worker_filter}
                placeholder="Search worker…"
                class="input input-bordered input-sm w-56"
                autocomplete="off"
                phx-debounce="300"
              />

              <.button
                :if={filters_active?(assigns)}
                variant="ghost"
                size="sm"
                phx-click="clear_filters"
              >
                Clear
              </.button>
            </form>
          </:header_actions>

          <%= if @result.entries == [] do %>
            <.empty_state
              icon="hero-queue-list"
              title="No matching jobs"
              description={empty_description(assigns)}
            />
          <% else %>
            <.data_table>
              <:col label="State" />
              <:col label="Worker" />
              <:col label="Queue" />
              <:col label="Attempts" align="right" />
              <:col label="Inserted" align="right" />
              <:col label="Last event" align="right" />
              <:row>
                <tr
                  :for={job <- @result.entries}
                  phx-click="show_detail"
                  phx-value-id={job.id}
                  class="cursor-pointer hover:bg-base-200/60"
                >
                  <td>
                    <.badge variant={state_variant(job.state)}>{job.state}</.badge>
                  </td>
                  <td class="font-mono text-xs text-base-content">{short_worker(job.worker)}</td>
                  <td class="font-mono text-xs text-base-content/70">{job.queue}</td>
                  <td class="text-right tabular-nums text-base-content/80">
                    {job.attempt}/{job.max_attempts}
                  </td>
                  <td class="text-right text-xs text-base-content/60">
                    {Tokens.format_datetime(job.inserted_at)}
                  </td>
                  <td class="text-right text-xs text-base-content/60">
                    {Tokens.format_datetime(job_event_time(job))}
                  </td>
                </tr>
              </:row>
            </.data_table>

            <%!-- Pagination --%>
            <footer
              :if={@result.page_count > 1}
              class="mt-3 flex items-center justify-between border-t border-base-200 pt-3"
            >
              <p class="ds-caption">
                Page {@result.page} of {@result.page_count}
              </p>
              <div class="flex items-center gap-2">
                <.button
                  variant="ghost"
                  size="sm"
                  icon="hero-chevron-left"
                  phx-click="prev_page"
                  disabled={@result.page <= 1}
                >
                  Previous
                </.button>
                <.button
                  variant="ghost"
                  size="sm"
                  phx-click="next_page"
                  disabled={@result.page >= @result.page_count}
                >
                  Next
                </.button>
              </div>
            </footer>
          <% end %>
        </.card>
      </div>
    </WraftDocWeb.AdminNext.Layouts.app>
    """
  end

  # ---------------------------------------------------------------------------
  # Show view
  # ---------------------------------------------------------------------------

  defp show_view(%{selected: nil} = assigns) do
    ~H"""
    <WraftDocWeb.AdminNext.Layouts.app {assigns}>
      <div class="space-y-6">
        <.page_header title="Job not found" description="This job no longer exists — it may have been pruned after completion.">
          <:eyebrow>Automation & Integrations · Queue Monitoring</:eyebrow>
          <:actions>
            <.button variant="neutral" icon="hero-arrow-left" navigate="/admin/queue-monitoring">
              Back to queues
            </.button>
          </:actions>
        </.page_header>

        <.card>
          <.empty_state
            icon="hero-queue-list"
            title="No matching job"
            description="The Oban Pruner removes completed jobs after 60 seconds by default. Failed and scheduled jobs are retained until manually removed or completed."
          />
        </.card>
      </div>
    </WraftDocWeb.AdminNext.Layouts.app>
    """
  end

  defp show_view(assigns) do
    ~H"""
    <WraftDocWeb.AdminNext.Layouts.app {assigns}>
      <div class="space-y-6">
        <.page_header
          title={short_worker(@selected.worker)}
          description={"Job ##{@selected.id} on queue #{@selected.queue}"}
        >
          <:eyebrow>Automation & Integrations · Queue Monitoring</:eyebrow>
          <:status>
            <.badge variant={state_variant(@selected.state)}>{@selected.state}</.badge>
          </:status>
          <:actions>
            <.button variant="neutral" icon="hero-arrow-left" navigate="/admin/queue-monitoring">
              Back to queues
            </.button>
          </:actions>
        </.page_header>

        <.card title="Job details">
          <dl class="grid grid-cols-1 gap-y-4 text-sm sm:grid-cols-2 lg:grid-cols-4">
            <div>
              <dt class="ds-caption">State</dt>
              <dd class="mt-1">
                <.badge variant={state_variant(@selected.state)}>{@selected.state}</.badge>
              </dd>
            </div>
            <div>
              <dt class="ds-caption">Queue</dt>
              <dd class="mt-1 font-mono text-xs text-base-content">{@selected.queue}</dd>
            </div>
            <div>
              <dt class="ds-caption">Worker</dt>
              <dd class="mt-1 font-mono text-xs break-words text-base-content">
                {@selected.worker}
              </dd>
            </div>
            <div>
              <dt class="ds-caption">Attempts</dt>
              <dd class="mt-1 tabular-nums text-base-content">
                {@selected.attempt} / {@selected.max_attempts}
              </dd>
            </div>
            <div>
              <dt class="ds-caption">Priority</dt>
              <dd class="mt-1 tabular-nums text-base-content">{@selected.priority || "—"}</dd>
            </div>
            <div>
              <dt class="ds-caption">Inserted</dt>
              <dd class="mt-1 text-base-content">
                {Tokens.format_datetime(@selected.inserted_at)}
              </dd>
            </div>
            <div>
              <dt class="ds-caption">Scheduled</dt>
              <dd class="mt-1 text-base-content">
                {Tokens.format_datetime(@selected.scheduled_at)}
              </dd>
            </div>
            <div>
              <dt class="ds-caption">Attempted</dt>
              <dd class="mt-1 text-base-content">
                {Tokens.format_datetime(@selected.attempted_at)}
              </dd>
            </div>
            <div>
              <dt class="ds-caption">Completed</dt>
              <dd class="mt-1 text-base-content">
                {Tokens.format_datetime(@selected.completed_at)}
              </dd>
            </div>
            <div>
              <dt class="ds-caption">Discarded</dt>
              <dd class="mt-1 text-base-content">
                {Tokens.format_datetime(@selected.discarded_at)}
              </dd>
            </div>
            <div>
              <dt class="ds-caption">Cancelled</dt>
              <dd class="mt-1 text-base-content">
                {Tokens.format_datetime(@selected.cancelled_at)}
              </dd>
            </div>
            <div :if={@selected.tags != []}>
              <dt class="ds-caption">Tags</dt>
              <dd class="mt-1 flex flex-wrap gap-1">
                <.badge :for={tag <- @selected.tags} variant="neutral">{tag}</.badge>
              </dd>
            </div>
          </dl>
        </.card>

        <.card title="Arguments">
          <pre class="overflow-x-auto rounded bg-base-200/40 p-3 font-mono text-xs text-base-content">{format_json(@selected.args)}</pre>
        </.card>

        <.card :if={map_size(@selected.meta || %{}) > 0} title="Meta">
          <pre class="overflow-x-auto rounded bg-base-200/40 p-3 font-mono text-xs text-base-content">{format_json(@selected.meta)}</pre>
        </.card>

        <.card
          :if={@selected.errors != []}
          title="Errors"
          caption={"#{length(@selected.errors)} attempt(s) failed"}
        >
          <div class="space-y-3">
            <div :for={{err, idx} <- Enum.with_index(@selected.errors)} class="rounded border border-base-200">
              <div class="flex items-center justify-between gap-2 border-b border-base-200 bg-base-200/30 px-3 py-1.5 text-xs">
                <span class="font-medium text-base-content">Attempt {error_attempt(err, idx)}</span>
                <span class="text-base-content/60">{error_at(err)}</span>
              </div>
              <pre class="overflow-x-auto p-3 font-mono text-xs text-error/90 whitespace-pre-wrap">{error_body(err)}</pre>
            </div>
          </div>
        </.card>
      </div>
    </WraftDocWeb.AdminNext.Layouts.app>
    """
  end

  # ---------------------------------------------------------------------------
  # View helpers
  # ---------------------------------------------------------------------------

  defp state_variant("executing"), do: "primary"
  defp state_variant("available"), do: "neutral"
  defp state_variant("scheduled"), do: "neutral"
  defp state_variant("completed"), do: "success"
  defp state_variant("retryable"), do: "warning"
  defp state_variant("discarded"), do: "error"
  defp state_variant("cancelled"), do: "error"
  defp state_variant(_), do: "ghost"

  # The Oban worker module name is a long fully-qualified string. Strip the
  # top-level `WraftDoc.` / `Elixir.` prefix for a tighter table cell.
  defp short_worker(nil), do: "—"

  defp short_worker(worker) when is_binary(worker) do
    worker
    |> String.replace_prefix("Elixir.", "")
    |> String.replace_prefix("WraftDoc.", "")
  end

  defp last_error(%{errors: []}), do: "—"

  defp last_error(%{errors: errors}) do
    errors
    |> List.last()
    |> error_body()
    |> String.split("\n")
    |> List.first()
    |> Kernel.||("—")
  end

  defp error_body(%{"error" => msg}) when is_binary(msg), do: msg
  defp error_body(%{"message" => msg}) when is_binary(msg), do: msg
  defp error_body(other) when is_map(other), do: format_json(other)
  defp error_body(other), do: inspect(other)

  defp error_attempt(%{"attempt" => a}, _idx), do: a
  defp error_attempt(_err, idx), do: idx + 1

  defp error_at(%{"at" => at}) when is_binary(at), do: at
  defp error_at(_), do: ""

  defp format_json(value) do
    case Jason.encode(value, pretty: true) do
      {:ok, json} -> json
      {:error, _} -> inspect(value, pretty: true)
    end
  end

  # Pick the most relevant timestamp for the row in the activity/failures
  # tables — whichever state-transition timestamp is most recent.
  defp job_event_time(%Oban.Job{} = j) do
    j
    |> Map.take([:completed_at, :discarded_at, :cancelled_at, :attempted_at, :scheduled_at, :inserted_at])
    |> Map.values()
    |> Enum.reject(&is_nil/1)
    |> case do
      [] -> nil
      times -> Enum.max(times, DateTime)
    end
  end

  defp result_caption(%{total: 0}), do: "No matching jobs."

  defp result_caption(%{total: total, page: page, page_size: page_size, entries: entries}) do
    first = (page - 1) * page_size + 1
    last = first + length(entries) - 1
    "Showing #{first}–#{last} of #{total} jobs"
  end

  defp filters_active?(%{state_filter: s, queue_filter: q, worker_filter: w}),
    do: s != "" or q != "" or w != ""

  defp filters_active?(_), do: false

  defp empty_description(assigns) do
    if filters_active?(assigns),
      do: "Try clearing the filters or broadening your search.",
      else: "Once background workers run, their jobs will appear here."
  end

  defp queue_caption(queue_rows, refreshed_at) do
    total = Enum.sum(Enum.map(queue_rows, & &1.total))

    "Tracking #{length(queue_rows)} queue(s) · #{total} job(s) · Refreshed " <>
      Tokens.format_datetime(refreshed_at)
  end

  # Build the assigns map the producer_badge component needs from a row.
  defp assigns_for_producer(row), do: %{producer: row.producer}

  defp producer_badge(assigns) do
    ~H"""
    <%= case @producer do %>
      <% nil -> %>
        <span class="ds-caption">Not running locally</span>
      <% %{paused: true} -> %>
        <.badge variant="warning">Paused</.badge>
      <% %{running: running} when is_list(running) -> %>
        <.badge variant="success">
          {length(running)} running
        </.badge>
      <% _ -> %>
        <.badge variant="success">Running</.badge>
    <% end %>
    """
  end

  defp overall_variant(%{total: 0}, %{inserted: 0}), do: "neutral"

  defp overall_variant(summary, _throughput) do
    cond do
      (summary["discarded"] || 0) > 0 -> "warning"
      (summary["retryable"] || 0) > 0 -> "warning"
      true -> "success"
    end
  end

  defp overall_label(%{total: 0}, %{inserted: 0}), do: "No job activity"

  defp overall_label(summary, _throughput) do
    cond do
      (summary["discarded"] || 0) > 0 -> "Some jobs discarded"
      (summary["retryable"] || 0) > 0 -> "Some retries pending"
      true -> "All queues healthy"
    end
  end
end
