defmodule WraftDocWeb.AdminNext.PipelineMetricsLive do
  @moduledoc """
  Admin LiveView for pipeline run telemetry at `/admin/pipeline-metrics`.

  Surfaces the `trigger_history` table — one row per pipeline execution
  — with the same dashboard layout as Build Metrics: counts (including
  in-flight), error rate, duration percentiles, throughput chart,
  slowest / failed lists, and a filtered activity table.

  Routes:

  - `:index` — `/admin/pipeline-metrics`
  - `:show`  — `/admin/pipeline-metrics/:id` (renders `data`,
    `response`, `error`, parent pipeline)

  Auto-refreshes every 30 seconds while connected.
  """
  use Phoenix.LiveView

  import WraftDocWeb.AdminNext.UI

  alias WraftDoc.Admin.MetricRange
  alias WraftDoc.Admin.PipelineMetrics
  alias WraftDocWeb.AdminNext.UI.Tokens

  @page_size 25
  @refresh_ms 30_000

  @index_path "/admin/pipeline-metrics"

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: schedule_refresh()

    {:ok,
     socket
     |> assign(:page_size, @page_size)
     |> assign(:page, 1)
     |> assign(:status_filter, "")
     |> assign(:organisation_filter, "")
     |> assign(:range, MetricRange.default())
     |> assign(:summary, empty_summary())
     |> assign(:series, [])
     |> assign(:slowest, [])
     |> assign(:recent_failures, [])
     |> assign(:result, empty_result())
     |> assign(:organisation_options, [])
     |> assign(:selected, nil)
     |> assign(:return_to, @index_path)
     |> assign(:initial_load?, true)
     |> assign(:last_refreshed_at, DateTime.utc_now())}
  end

  @impl true
  def handle_params(params, _url, %{assigns: %{live_action: :show}} = socket) do
    {:noreply,
     socket
     |> assign(:page_title, "Pipeline run")
     |> assign(:selected, PipelineMetrics.get(params["id"]))
     |> assign(:return_to, sanitise_return_to(params["return_to"]))}
  end

  def handle_params(params, _url, socket) do
    was_initial = Map.get(socket.assigns, :initial_load?, false)
    old_sig = filter_signature(socket.assigns)

    socket =
      socket
      |> assign(:page_title, "Pipeline Metrics")
      |> assign(:selected, nil)
      |> assign(:range, MetricRange.parse(params))
      |> assign(:status_filter, params["status"] || "")
      |> assign(:organisation_filter, params["organisation_id"] || "")
      |> assign(:page, parse_page(params["page"]))
      |> assign(:initial_load?, false)

    socket =
      if was_initial or old_sig != filter_signature(socket.assigns) do
        load_all(socket)
      else
        load_jobs(socket)
      end

    {:noreply, socket}
  end

  defp filter_signature(%{
         range: range,
         status_filter: status,
         organisation_filter: org
       }) do
    {range_signature(range), status, org}
  end

  defp filter_signature(_), do: nil

  defp range_signature(%MetricRange{preset: "custom", from: from, to: to}),
    do: {"custom", DateTime.to_date(from), DateTime.to_date(to)}

  defp range_signature(%MetricRange{preset: preset}), do: preset
  defp range_signature(_), do: nil

  # ---------------------------------------------------------------------------
  # Events
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("set_range", %{"preset" => "custom"}, socket) do
    range = socket.assigns.range

    {:noreply,
     navigate_to(socket, %{
       "preset" => "custom",
       "from" => MetricRange.from_date_string(range),
       "to" => MetricRange.to_date_string(range),
       "page" => nil
     })}
  end

  def handle_event("set_range", %{"preset" => preset}, socket) do
    {:noreply,
     navigate_to(socket, %{
       "preset" => preset,
       "from" => nil,
       "to" => nil,
       "page" => nil
     })}
  end

  def handle_event("set_custom_range", params, socket) do
    range = socket.assigns.range

    {:noreply,
     navigate_to(socket, %{
       "preset" => "custom",
       "from" => nonempty(params["from"]) || MetricRange.from_date_string(range),
       "to" => nonempty(params["to"]) || MetricRange.to_date_string(range),
       "page" => nil
     })}
  end

  def handle_event("filter", params, socket) do
    {:noreply,
     navigate_to(socket, %{
       "status" => params["status"] || "",
       "organisation_id" => params["organisation_id"] || "",
       "page" => nil
     })}
  end

  def handle_event("clear_filters", _params, socket) do
    {:noreply,
     navigate_to(socket, %{
       "status" => nil,
       "organisation_id" => nil,
       "page" => nil
     })}
  end

  def handle_event("prev_page", _params, socket) do
    new_page = max(socket.assigns.page - 1, 1)
    {:noreply, navigate_to(socket, %{"page" => page_param(new_page)})}
  end

  def handle_event("next_page", _params, socket) do
    %{page: page, result: %{page_count: page_count}} = socket.assigns
    new_page = min(page + 1, max(page_count, 1))
    {:noreply, navigate_to(socket, %{"page" => page_param(new_page)})}
  end

  def handle_event("refresh", _params, socket) do
    {:noreply, load_all(socket)}
  end

  def handle_event("show_detail", %{"id" => id}, socket) do
    return_to = current_index_url(socket.assigns)

    target =
      "/admin/pipeline-metrics/#{URI.encode(to_string(id))}?" <>
        URI.encode_query(%{"return_to" => return_to})

    {:noreply, push_navigate(socket, to: target)}
  end

  # ---------------------------------------------------------------------------
  # URL state
  # ---------------------------------------------------------------------------

  defp navigate_to(socket, overrides) do
    query =
      socket.assigns
      |> current_state()
      |> Map.merge(overrides)
      |> to_query_string()

    target = if query == "", do: @index_path, else: @index_path <> "?" <> query
    push_patch(socket, to: target)
  end

  defp current_index_url(assigns) do
    query = assigns |> current_state() |> to_query_string()
    if query == "", do: @index_path, else: @index_path <> "?" <> query
  end

  defp to_query_string(state) do
    state
    |> Enum.reject(fn {_k, v} -> v in [nil, ""] end)
    |> Enum.into(%{})
    |> URI.encode_query()
  end

  defp sanitise_return_to(path) when is_binary(path) do
    if String.starts_with?(path, @index_path), do: path, else: @index_path
  end

  defp sanitise_return_to(_), do: @index_path

  defp current_state(assigns) do
    range = assigns.range

    %{
      "preset" => range.preset,
      "from" => if(range.preset == "custom", do: MetricRange.from_date_string(range), else: nil),
      "to" => if(range.preset == "custom", do: MetricRange.to_date_string(range), else: nil),
      "status" => assigns.status_filter,
      "organisation_id" => assigns.organisation_filter,
      "page" => page_param(assigns.page)
    }
  end

  defp page_param(n) when is_integer(n) and n > 1, do: to_string(n)
  defp page_param(_), do: nil

  defp nonempty(s) when is_binary(s) and s != "", do: s
  defp nonempty(_), do: nil

  defp parse_page(nil), do: 1
  defp parse_page(""), do: 1

  defp parse_page(str) when is_binary(str) do
    case Integer.parse(str) do
      {n, _} when n > 0 -> n
      _ -> 1
    end
  end

  defp parse_page(_), do: 1

  @impl true
  def handle_info(:refresh, socket) do
    schedule_refresh()

    case socket.assigns.live_action do
      :show ->
        id = socket.assigns.selected && socket.assigns.selected.id
        {:noreply, assign(socket, :selected, PipelineMetrics.get(id))}

      _ ->
        {:noreply, load_all(socket)}
    end
  end

  defp schedule_refresh, do: Process.send_after(self(), :refresh, @refresh_ms)

  # ---------------------------------------------------------------------------
  # Data loading
  # ---------------------------------------------------------------------------

  defp load_all(socket) do
    %{range: range, organisation_filter: org} = socket.assigns
    opts = [organisation_id: org]

    socket
    |> assign(:summary, PipelineMetrics.summary(range, opts))
    |> assign(:series, PipelineMetrics.time_series(range, opts))
    |> assign(:slowest, PipelineMetrics.slowest(range, opts, 5))
    |> assign(:recent_failures, PipelineMetrics.recent_failures(range, opts, 5))
    |> assign(:organisation_options, PipelineMetrics.organisation_options())
    |> assign(:last_refreshed_at, DateTime.utc_now())
    |> load_jobs()
  end

  defp load_jobs(socket) do
    %{
      page: page,
      page_size: page_size,
      status_filter: status,
      organisation_filter: org,
      range: range
    } = socket.assigns

    result =
      PipelineMetrics.list(
        page: page,
        page_size: page_size,
        status: status,
        organisation_id: org,
        range: range
      )

    assign(socket, :result, result)
  end

  defp empty_summary do
    %{
      total: 0,
      success: 0,
      failed: 0,
      in_flight: 0,
      error_rate: nil,
      avg_ms: nil,
      p95_ms: nil
    }
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
          title="Pipeline Metrics"
          description="Pipeline run health across every organisation. Counts and durations come from the trigger_history table; failures preserve the error payload for triage."
        >
          <:eyebrow>Automation & Integrations</:eyebrow>
          <:status>
            <.status_pill variant={overall_variant(@summary)}>
              {overall_label(@summary)}
            </.status_pill>
          </:status>
          <:actions>
            <.button variant="neutral" icon="hero-arrow-path" phx-click="refresh">
              Refresh
            </.button>
          </:actions>
        </.page_header>

        <%!-- Range + organisation controls --%>
        <.card>
          <:header_actions>
            <.segmented
              current={@range.preset}
              options={MetricRange.presets()}
              event="set_range"
              param="preset"
            />
          </:header_actions>

          <div class="flex flex-wrap items-center gap-3">
            <form
              :if={@range.preset == "custom"}
              phx-change="set_custom_range"
              phx-submit="set_custom_range"
              class="flex flex-wrap items-center gap-2"
            >
              <label class="ds-caption">From</label>
              <input
                type="date"
                name="from"
                value={MetricRange.from_date_string(@range)}
                class="input input-bordered input-sm"
                phx-debounce="300"
              />
              <label class="ds-caption">To</label>
              <input
                type="date"
                name="to"
                value={MetricRange.to_date_string(@range)}
                class="input input-bordered input-sm"
                phx-debounce="300"
              />
            </form>

            <form phx-change="filter" class="flex flex-wrap items-center gap-2">
              <select name="organisation_id" class="select select-bordered select-sm">
                <option value="" selected={@organisation_filter == ""}>All organisations</option>
                <option
                  :for={org <- @organisation_options}
                  value={org.id}
                  selected={@organisation_filter == org.id}
                >
                  {org.name}
                </option>
              </select>
              <input type="hidden" name="status" value={@status_filter} />
              <.button
                :if={filters_active?(assigns)}
                variant="ghost"
                size="sm"
                phx-click="clear_filters"
              >
                Clear
              </.button>
            </form>

            <span class="ml-auto ds-caption">
              {@range.label} · Refreshed {Tokens.format_datetime(@last_refreshed_at)}
            </span>
          </div>
        </.card>

        <%!-- Summary stat cards --%>
        <section class="grid grid-cols-2 gap-4 sm:grid-cols-4 lg:grid-cols-7">
          <.mini_stat icon="hero-arrows-right-left" label="Total runs" value={@summary.total} />
          <.mini_stat icon="hero-check-circle" label="Succeeded" value={@summary.success} />
          <.mini_stat icon="hero-x-circle" label="Failed" value={@summary.failed} />
          <.mini_stat icon="hero-bolt" label="In flight" value={@summary.in_flight} />
          <.mini_stat icon="hero-exclamation-triangle" label="Error rate" value={format_rate(@summary.error_rate)} />
          <.mini_stat icon="hero-clock" label="Avg duration" value={format_ms(@summary.avg_ms)} />
          <.mini_stat icon="hero-chart-bar" label="p95 duration" value={format_ms(@summary.p95_ms)} />
        </section>

        <%!-- Time-series chart --%>
        <.card
          title="Pipeline throughput"
          caption={series_caption(@series, @range)}
        >
          <.area_chart series={@series} accent={chart_accent(@summary)} height={200} />
        </.card>

        <%!-- Slowest + recent failures --%>
        <section class="grid grid-cols-1 gap-4 lg:grid-cols-2">
          <.card
            title="Slowest runs"
            caption="Top 5 by duration in the selected window."
          >
            <%= if @slowest == [] do %>
              <.empty_state
                icon="hero-clock"
                title="No timing data"
                description="No completed pipeline runs in this window."
              />
            <% else %>
              <.data_table>
                <:col label="Pipeline" />
                <:col label="Organisation" />
                <:col label="Duration" align="right" />
                <:col label="State" />
                <:col label="When" align="right" />
                <:row>
                  <tr
                    :for={t <- @slowest}
                    phx-click="show_detail"
                    phx-value-id={t.id}
                    class="cursor-pointer hover:bg-base-200/60"
                  >
                    <td class="font-medium text-base-content">{pipeline_name(t)}</td>
                    <td class="text-xs text-base-content/70">{organisation_name(t)}</td>
                    <td class="text-right tabular-nums font-medium text-base-content">
                      {format_ms(t.duration)}
                    </td>
                    <td>
                      <.badge variant={PipelineMetrics.state_variant(t.state)}>
                        {PipelineMetrics.state_label(t.state)}
                      </.badge>
                    </td>
                    <td class="text-right text-xs text-base-content/60">
                      {Tokens.format_datetime(t.end_time || t.inserted_at)}
                    </td>
                  </tr>
                </:row>
              </.data_table>
            <% end %>
          </.card>

          <.card
            title="Recent failures"
            caption="Failed or partially-completed runs — newest first."
          >
            <%= if @recent_failures == [] do %>
              <.empty_state
                icon="hero-check-badge"
                title="No recent failures"
                description="Every pipeline run in this window completed cleanly."
              />
            <% else %>
              <.data_table>
                <:col label="State" />
                <:col label="Pipeline" />
                <:col label="Organisation" />
                <:col label="Error" />
                <:col label="When" align="right" />
                <:row>
                  <tr
                    :for={t <- @recent_failures}
                    phx-click="show_detail"
                    phx-value-id={t.id}
                    class="cursor-pointer hover:bg-base-200/60 align-top"
                  >
                    <td>
                      <.badge variant={PipelineMetrics.state_variant(t.state)}>
                        {PipelineMetrics.state_label(t.state)}
                      </.badge>
                    </td>
                    <td class="font-medium text-base-content">{pipeline_name(t)}</td>
                    <td class="text-xs text-base-content/70">{organisation_name(t)}</td>
                    <td class="max-w-[24rem] truncate font-mono text-xs text-error/90">
                      {error_summary(t)}
                    </td>
                    <td class="text-right text-xs text-base-content/60">
                      {Tokens.format_datetime(t.inserted_at)}
                    </td>
                  </tr>
                </:row>
              </.data_table>
            <% end %>
          </.card>
        </section>

        <%!-- Activity table --%>
        <.card
          title="Activity"
          caption={result_caption(@result)}
        >
          <:header_actions>
            <form phx-change="filter" class="flex flex-wrap items-center gap-2">
              <select name="status" class="select select-bordered select-sm">
                <option value="" selected={@status_filter == ""}>All states</option>
                <option
                  :for={s <- PipelineMetrics.statuses()}
                  value={s}
                  selected={@status_filter == s}
                >
                  {status_option_label(s)}
                </option>
              </select>
              <input type="hidden" name="organisation_id" value={@organisation_filter} />
            </form>
          </:header_actions>

          <%= if @result.entries == [] do %>
            <.empty_state
              icon="hero-arrows-right-left"
              title="No pipeline runs match"
              description={empty_description(assigns)}
            />
          <% else %>
            <.data_table>
              <:col label="State" />
              <:col label="Pipeline" />
              <:col label="Organisation" />
              <:col label="Creator" />
              <:col label="Duration" align="right" />
              <:col label="Started" align="right" />
              <:row>
                <tr
                  :for={t <- @result.entries}
                  phx-click="show_detail"
                  phx-value-id={t.id}
                  class="cursor-pointer hover:bg-base-200/60"
                >
                  <td>
                    <.badge variant={PipelineMetrics.state_variant(t.state)}>
                      {PipelineMetrics.state_label(t.state)}
                    </.badge>
                  </td>
                  <td class="font-medium text-base-content">{pipeline_name(t)}</td>
                  <td class="text-xs text-base-content/70">{organisation_name(t)}</td>
                  <td class="text-xs text-base-content/70">{creator_name(t)}</td>
                  <td class="text-right tabular-nums text-base-content">{format_ms(t.duration)}</td>
                  <td class="text-right text-xs text-base-content/60">
                    {Tokens.format_datetime(t.start_time || t.inserted_at)}
                  </td>
                </tr>
              </:row>
            </.data_table>

            <footer
              :if={@result.page_count > 1}
              class="mt-3 flex items-center justify-between border-t border-base-200 pt-3"
            >
              <p class="ds-caption">Page {@result.page} of {@result.page_count}</p>
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
        <.page_header
          title="Pipeline run not found"
          description="This trigger no longer exists or the link is malformed."
        >
          <:eyebrow>Automation & Integrations · Pipeline Metrics</:eyebrow>
          <:actions>
            <.button variant="neutral" icon="hero-arrow-left" navigate={@return_to}>
              Back to metrics
            </.button>
          </:actions>
        </.page_header>
      </div>
    </WraftDocWeb.AdminNext.Layouts.app>
    """
  end

  defp show_view(assigns) do
    ~H"""
    <WraftDocWeb.AdminNext.Layouts.app {assigns}>
      <div class="space-y-6">
        <.page_header
          title={pipeline_name(@selected)}
          description={"Trigger #{@selected.id}"}
        >
          <:eyebrow>Automation & Integrations · Pipeline Metrics</:eyebrow>
          <:status>
            <.badge variant={PipelineMetrics.state_variant(@selected.state)}>
              {PipelineMetrics.state_label(@selected.state)}
            </.badge>
          </:status>
          <:actions>
            <.button variant="neutral" icon="hero-arrow-left" navigate={@return_to}>
              Back to metrics
            </.button>
          </:actions>
        </.page_header>

        <.card title="Run details">
          <dl class="grid grid-cols-1 gap-y-4 text-sm sm:grid-cols-2 lg:grid-cols-4">
            <div>
              <dt class="ds-caption">State</dt>
              <dd class="mt-1">
                <.badge variant={PipelineMetrics.state_variant(@selected.state)}>
                  {PipelineMetrics.state_label(@selected.state)}
                </.badge>
              </dd>
            </div>
            <div>
              <dt class="ds-caption">Duration</dt>
              <dd class="mt-1 tabular-nums text-base-content">{format_ms(@selected.duration)}</dd>
            </div>
            <div>
              <dt class="ds-caption">Pipeline</dt>
              <dd class="mt-1 font-medium text-base-content">{pipeline_name(@selected)}</dd>
            </div>
            <div>
              <dt class="ds-caption">Organisation</dt>
              <dd class="mt-1 text-base-content">{organisation_name(@selected)}</dd>
            </div>
            <div>
              <dt class="ds-caption">Creator</dt>
              <dd class="mt-1 text-base-content">{creator_name(@selected)}</dd>
            </div>
            <div>
              <dt class="ds-caption">Started</dt>
              <dd class="mt-1 text-base-content">{Tokens.format_datetime(@selected.start_time)}</dd>
            </div>
            <div>
              <dt class="ds-caption">Ended</dt>
              <dd class="mt-1 text-base-content">{Tokens.format_datetime(@selected.end_time)}</dd>
            </div>
            <div>
              <dt class="ds-caption">Inserted</dt>
              <dd class="mt-1 text-base-content">{Tokens.format_datetime(@selected.inserted_at)}</dd>
            </div>
            <div :if={@selected.zip_file}>
              <dt class="ds-caption">Output</dt>
              <dd class="mt-1 font-mono text-xs break-words text-base-content">
                {@selected.zip_file}
              </dd>
            </div>
          </dl>
        </.card>

        <.card :if={has_payload?(@selected.error)} title="Error">
          <pre class="overflow-x-auto rounded bg-base-200/40 p-3 font-mono text-xs text-error/90 whitespace-pre-wrap">{format_json(@selected.error)}</pre>
        </.card>

        <.card :if={has_payload?(@selected.data)} title="Input">
          <pre class="overflow-x-auto rounded bg-base-200/40 p-3 font-mono text-xs text-base-content">{format_json(@selected.data)}</pre>
        </.card>

        <.card :if={has_payload?(@selected.response)} title="Response">
          <pre class="overflow-x-auto rounded bg-base-200/40 p-3 font-mono text-xs text-base-content">{format_json(@selected.response)}</pre>
        </.card>
      </div>
    </WraftDocWeb.AdminNext.Layouts.app>
    """
  end

  # ---------------------------------------------------------------------------
  # View helpers
  # ---------------------------------------------------------------------------

  defp pipeline_name(%{pipeline: %{name: name}}) when is_binary(name), do: name
  defp pipeline_name(_), do: "—"

  defp organisation_name(%{pipeline: %{organisation: %{name: name}}}) when is_binary(name),
    do: name

  defp organisation_name(_), do: "—"

  defp creator_name(%{creator: %{name: name}}) when is_binary(name), do: name
  defp creator_name(%{creator: %{email: email}}) when is_binary(email), do: email
  defp creator_name(_), do: "—"

  defp format_ms(nil), do: "—"
  defp format_ms(n) when is_integer(n) and n < 1000, do: "#{n} ms"
  defp format_ms(n) when is_integer(n), do: "#{Float.round(n / 1000, 2)} s"
  defp format_ms(other), do: to_string(other)

  defp format_rate(nil), do: "—"
  defp format_rate(rate) when is_number(rate), do: "#{rate}%"

  defp series_caption(series, range) do
    total = series |> Enum.map(& &1.count) |> Enum.sum()
    "#{total} runs · #{range.label}"
  end

  defp result_caption(%{total: 0}), do: "No matching pipeline runs."

  defp result_caption(%{total: total, page: page, page_size: page_size, entries: entries}) do
    first = (page - 1) * page_size + 1
    last = first + length(entries) - 1
    "Showing #{first}–#{last} of #{total} runs"
  end

  defp filters_active?(%{status_filter: s, organisation_filter: o}),
    do: s != "" or o != ""

  defp filters_active?(_), do: false

  defp empty_description(assigns) do
    if filters_active?(assigns),
      do: "Try clearing the filters or widening the date range.",
      else: "No pipeline runs were recorded in this window."
  end

  defp status_option_label("success"), do: "Success"
  defp status_option_label("failed"), do: "Failed"
  defp status_option_label("in_flight"), do: "In flight"
  defp status_option_label(other), do: String.capitalize(other)

  defp overall_variant(%{total: 0}), do: "neutral"
  defp overall_variant(%{error_rate: rate}) when is_number(rate) and rate >= 10.0, do: "error"
  defp overall_variant(%{error_rate: rate}) when is_number(rate) and rate > 0.0, do: "warning"
  defp overall_variant(_), do: "success"

  defp overall_label(%{total: 0}), do: "No pipeline activity"

  defp overall_label(%{error_rate: rate}) when is_number(rate) and rate >= 10.0,
    do: "Elevated failures"

  defp overall_label(%{error_rate: rate}) when is_number(rate) and rate > 0.0, do: "Some failures"
  defp overall_label(_), do: "All pipelines healthy"

  defp chart_accent(%{error_rate: r}) when is_number(r) and r >= 10.0, do: "error"
  defp chart_accent(%{error_rate: r}) when is_number(r) and r > 0.0, do: "warning"
  defp chart_accent(_), do: "primary"

  defp has_payload?(payload) when is_map(payload), do: map_size(payload) > 0
  defp has_payload?(_), do: false

  defp error_summary(%{error: payload}) when is_map(payload) and map_size(payload) > 0 do
    payload
    |> first_string_value()
    |> Kernel.||(format_json(payload))
    |> String.split("\n")
    |> List.first()
    |> Kernel.||("—")
  end

  defp error_summary(_), do: "—"

  defp first_string_value(map) when is_map(map) do
    Enum.find_value(map, fn
      {_k, v} when is_binary(v) -> v
      _ -> nil
    end)
  end

  defp format_json(value) do
    case Jason.encode(value, pretty: true) do
      {:ok, json} -> json
      {:error, _} -> inspect(value, pretty: true)
    end
  end
end
