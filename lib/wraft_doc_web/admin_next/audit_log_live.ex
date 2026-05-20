defmodule WraftDocWeb.AdminNext.AuditLogLive do
  @moduledoc """
  Admin LiveView for the system-wide audit log at `/admin/audit-logs`.

  Surfaces rows from the `ex_audit_version` table — every create / update /
  delete on a tracked schema (configured in `config/config.exs` under
  `:ex_audit, :tracked_schemas`). Two views share this module:

  - `:index` — filterable, paginated table of recent events.
  - `:show`  — detail page for a single event with metadata + diff table,
    mirroring the Backpex resource flow (dedicated route, not a modal).

  Why a custom LiveView instead of a Backpex `LiveResource`: audit rows
  are immutable, the entity_schema is a custom Ecto type that doesn't
  fit Backpex's field types, and we need bespoke filters (action +
  schema dropdowns wired against the tracked-schemas config).
  """
  use Phoenix.LiveView

  import WraftDocWeb.AdminNext.UI

  alias Backpex.HTML.CoreComponents
  alias WraftDoc.Admin.AuditLogs
  alias WraftDoc.Admin.AuditLogs.Diff
  alias WraftDocWeb.AdminNext.UI.Tokens

  @page_size 25

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_size, @page_size)
     |> assign(:page, 1)
     |> assign(:action_filter, "")
     |> assign(:schema_filter, "")
     |> assign(:search, "")
     |> assign(:schema_options, schema_options())
     |> assign(:counts, AuditLogs.counts())
     |> assign(:result, empty_result())
     |> assign(:selected, nil)
     |> assign(:diff_rows, [])}
  end

  @impl true
  def handle_params(params, _url, %{assigns: %{live_action: :show}} = socket) do
    {:noreply,
     socket
     |> assign(:page_title, "Audit Event")
     |> assign_selected(params["id"])}
  end

  def handle_params(_params, _url, socket) do
    {:noreply,
     socket
     |> assign(:page_title, "Audit Logs")
     |> assign(:selected, nil)
     |> assign(:diff_rows, [])
     |> load_page()}
  end

  @impl true
  def handle_event("filter", params, socket) do
    {:noreply,
     socket
     |> assign(:action_filter, params["action"] || "")
     |> assign(:schema_filter, params["schema"] || "")
     |> assign(:search, params["q"] || "")
     |> assign(:page, 1)
     |> load_page()}
  end

  def handle_event("clear_filters", _params, socket) do
    {:noreply,
     socket
     |> assign(:action_filter, "")
     |> assign(:schema_filter, "")
     |> assign(:search, "")
     |> assign(:page, 1)
     |> load_page()}
  end

  def handle_event("prev_page", _params, socket) do
    {:noreply, socket |> assign(:page, max(socket.assigns.page - 1, 1)) |> load_page()}
  end

  def handle_event("next_page", _params, socket) do
    %{page: page, result: %{page_count: page_count}} = socket.assigns
    {:noreply, socket |> assign(:page, min(page + 1, max(page_count, 1))) |> load_page()}
  end

  def handle_event("show_detail", %{"id" => id}, socket) do
    {:noreply, push_navigate(socket, to: "/admin/audit-logs/#{URI.encode(to_string(id))}")}
  end

  # ---------------------------------------------------------------------------
  # Data loading
  # ---------------------------------------------------------------------------

  defp load_page(socket) do
    %{
      page: page,
      page_size: page_size,
      action_filter: action,
      schema_filter: schema,
      search: search
    } = socket.assigns

    result =
      AuditLogs.list(
        page: page,
        page_size: page_size,
        action: action,
        schema: schema,
        search: search
      )

    assign(socket, :result, result)
  end

  defp schema_options do
    AuditLogs.tracked_schemas()
    |> Enum.map(fn module -> {AuditLogs.schema_label(module), Atom.to_string(module)} end)
    |> Enum.sort_by(fn {label, _} -> label end)
  end

  defp assign_selected(socket, nil), do: assign(socket, selected: nil, diff_rows: [])
  defp assign_selected(socket, ""), do: assign(socket, selected: nil, diff_rows: [])

  defp assign_selected(socket, id) when is_binary(id) do
    case AuditLogs.get(id) do
      nil -> assign(socket, selected: nil, diff_rows: [])
      entry -> assign(socket, selected: entry, diff_rows: Diff.flatten(entry.patch))
    end
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
          title="Audit Logs"
          description="A system-wide record of every create, update, and delete on tracked schemas. Use the filters to narrow by action, entity type, or actor."
        >
          <:eyebrow>Security</:eyebrow>
        </.page_header>

        <%!-- Headline counts --%>
        <section class="grid grid-cols-2 gap-4 sm:grid-cols-4">
          <.mini_stat icon="hero-list-bullet" label="Total events" value={@counts.total} />
          <.mini_stat icon="hero-plus-circle" label="Created" value={@counts.created} />
          <.mini_stat icon="hero-pencil-square" label="Updated" value={@counts.updated} />
          <.mini_stat icon="hero-trash" label="Deleted" value={@counts.deleted} />
        </section>

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
              <select name="action" class="select select-bordered select-sm">
                <option value="" selected={@action_filter == ""}>All actions</option>
                <option
                  :for={a <- AuditLogs.actions()}
                  value={Atom.to_string(a)}
                  selected={@action_filter == Atom.to_string(a)}
                >
                  {action_label(a)}
                </option>
              </select>

              <select name="schema" class="select select-bordered select-sm">
                <option value="" selected={@schema_filter == ""}>All entities</option>
                <option
                  :for={{label, value} <- @schema_options}
                  value={value}
                  selected={@schema_filter == value}
                >
                  {label}
                </option>
              </select>

              <input
                type="search"
                name="q"
                value={@search}
                placeholder="Search by user name or email…"
                class="input input-bordered input-sm w-64"
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
              icon="hero-document-magnifying-glass"
              title="No audit events match"
              description={empty_description(assigns)}
            />
          <% else %>
            <.data_table>
              <:col label="Action" />
              <:col label="Entity" />
              <:col label="Entity ID" />
              <:col label="Changed by" />
              <:col label="Recorded" align="right" />
              <:row>
                <tr
                  :for={entry <- @result.entries}
                  phx-click="show_detail"
                  phx-value-id={entry.id}
                  class="cursor-pointer hover:bg-base-200/60"
                >
                  <td>
                    <.badge variant={action_variant(entry.action)}>
                      <CoreComponents.icon
                        name={action_icon(entry.action)}
                        class="size-3"
                      />
                      <span class="ml-1">{action_label(entry.action)}</span>
                    </.badge>
                    <span
                      :if={entry.rollback}
                      class="ml-1 text-[10px] uppercase tracking-wide text-base-content/50"
                    >
                      rollback
                    </span>
                  </td>
                  <td class="font-medium text-base-content">
                    {AuditLogs.schema_label(entry.entity_schema)}
                  </td>
                  <td class="font-mono text-xs text-base-content/70">
                    {short_id(entry.entity_id)}
                  </td>
                  <td>
                    <%= if entry.user do %>
                      <p class="font-medium text-base-content">{entry.user.name}</p>
                      <p class="font-mono text-xs text-base-content/55">{entry.user.email}</p>
                    <% else %>
                      <span class="text-xs text-base-content/50">System</span>
                    <% end %>
                  </td>
                  <td class="text-right text-xs text-base-content/60">
                    {Tokens.format_datetime(entry.recorded_at)}
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
  # Show view (per-event detail)
  # ---------------------------------------------------------------------------

  defp show_view(%{selected: nil} = assigns) do
    ~H"""
    <WraftDocWeb.AdminNext.Layouts.app {assigns}>
      <div class="space-y-6">
        <.page_header title="Audit event not found" description="This event no longer exists or the link is malformed.">
          <:eyebrow>Security</:eyebrow>
          <:actions>
            <.button variant="neutral" icon="hero-arrow-left" navigate="/admin/audit-logs">
              Back to audit logs
            </.button>
          </:actions>
        </.page_header>

        <.card>
          <.empty_state
            icon="hero-document-magnifying-glass"
            title="No matching audit event"
            description="The event may have been pruned, or the URL was edited. Return to the activity list to browse recent events."
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
          title={AuditLogs.schema_label(@selected.entity_schema)}
          description={"Audit event for #{@selected.entity_id}"}
        >
          <:eyebrow>Security · Audit Log</:eyebrow>
          <:status>
            <.badge variant={action_variant(@selected.action)}>
              <CoreComponents.icon name={action_icon(@selected.action)} class="size-3" />
              <span class="ml-1">{action_label(@selected.action)}</span>
            </.badge>
            <.badge :if={@selected.rollback} variant="warning">Rollback</.badge>
          </:status>
          <:actions>
            <.button variant="neutral" icon="hero-arrow-left" navigate="/admin/audit-logs">
              Back to audit logs
            </.button>
          </:actions>
        </.page_header>

        <.card title="Event details">
          <dl class="grid grid-cols-1 gap-y-4 text-sm sm:grid-cols-2 lg:grid-cols-4">
            <div>
              <dt class="ds-caption">Action</dt>
              <dd class="mt-1">
                <.badge variant={action_variant(@selected.action)}>
                  <CoreComponents.icon name={action_icon(@selected.action)} class="size-3" />
                  <span class="ml-1">{action_label(@selected.action)}</span>
                </.badge>
              </dd>
            </div>
            <div>
              <dt class="ds-caption">Entity</dt>
              <dd class="mt-1 font-medium text-base-content">
                {AuditLogs.schema_label(@selected.entity_schema)}
              </dd>
            </div>
            <div class="sm:col-span-2">
              <dt class="ds-caption">Entity ID</dt>
              <dd class="mt-1 font-mono text-xs text-base-content/70">
                {@selected.entity_id}
              </dd>
            </div>
            <div>
              <dt class="ds-caption">Changed by</dt>
              <dd class="mt-1">
                <%= if @selected.user do %>
                  <p class="font-medium text-base-content">{@selected.user.name}</p>
                  <p class="font-mono text-xs text-base-content/55">{@selected.user.email}</p>
                <% else %>
                  <span class="text-xs text-base-content/50">System</span>
                <% end %>
              </dd>
            </div>
            <div>
              <dt class="ds-caption">Recorded</dt>
              <dd class="mt-1 text-base-content">
                {Tokens.format_datetime(@selected.recorded_at)}
              </dd>
            </div>
            <div>
              <dt class="ds-caption">Rollback</dt>
              <dd class="mt-1 text-base-content">
                {if @selected.rollback, do: "Yes", else: "No"}
              </dd>
            </div>
            <div>
              <dt class="ds-caption">Event ID</dt>
              <dd class="mt-1 font-mono text-xs text-base-content/70">
                {@selected.id}
              </dd>
            </div>
          </dl>
        </.card>

        <.card
          title="Changes"
          caption={changes_caption(@diff_rows)}
        >
          <%= if @diff_rows == [] do %>
            <.empty_state
              icon="hero-document"
              title="No field-level changes recorded"
              description="This event has no diff payload — typically a metadata-only create or delete."
            />
          <% else %>
            <.data_table>
              <:col label="Field" />
              <:col label="Change" />
              <:col label="Previous" />
              <:col label="Current" />
              <:row>
                <tr :for={row <- @diff_rows} class="align-top">
                  <td class="font-mono text-xs font-medium text-base-content">
                    {row.path}
                  </td>
                  <td>
                    <.badge variant={diff_variant(row.kind)}>{diff_label(row.kind)}</.badge>
                  </td>
                  <td class="break-words font-mono text-xs">
                    <%= case row.kind do %>
                      <% :added -> %>
                        <span class="text-base-content/40">—</span>
                      <% kind when kind in [:removed, :changed] -> %>
                        <span class="text-error line-through">
                          {Diff.format_value(row.old)}
                        </span>
                    <% end %>
                  </td>
                  <td class="break-words font-mono text-xs">
                    <%= case row.kind do %>
                      <% :removed -> %>
                        <span class="text-base-content/40">—</span>
                      <% kind when kind in [:added, :changed] -> %>
                        <span class="text-success">
                          {Diff.format_value(row.new)}
                        </span>
                    <% end %>
                  </td>
                </tr>
              </:row>
            </.data_table>
          <% end %>
        </.card>
      </div>
    </WraftDocWeb.AdminNext.Layouts.app>
    """
  end

  # ---------------------------------------------------------------------------
  # View helpers
  # ---------------------------------------------------------------------------

  defp action_variant(:created), do: "success"
  defp action_variant(:updated), do: "primary"
  defp action_variant(:deleted), do: "error"
  defp action_variant(_), do: "neutral"

  defp action_icon(:created), do: "hero-plus-circle"
  defp action_icon(:updated), do: "hero-pencil-square"
  defp action_icon(:deleted), do: "hero-trash"
  defp action_icon(_), do: "hero-question-mark-circle"

  defp action_label(:created), do: "Created"
  defp action_label(:updated), do: "Updated"
  defp action_label(:deleted), do: "Deleted"
  defp action_label(other), do: Phoenix.Naming.humanize(other)

  defp diff_variant(:added), do: "success"
  defp diff_variant(:removed), do: "error"
  defp diff_variant(:changed), do: "primary"

  defp diff_label(:added), do: "Added"
  defp diff_label(:removed), do: "Removed"
  defp diff_label(:changed), do: "Changed"

  defp short_id(nil), do: "—"

  defp short_id(uuid) when is_binary(uuid) do
    case String.split(uuid, "-", parts: 2) do
      [head | _] -> head
      _ -> uuid
    end
  end

  defp filters_active?(%{action_filter: a, schema_filter: s, search: q}),
    do: a != "" or s != "" or q != ""

  defp filters_active?(_), do: false

  defp result_caption(%{total: 0}), do: "No matching events."

  defp result_caption(%{total: total, page: page, page_size: page_size, entries: entries}) do
    first = (page - 1) * page_size + 1
    last = first + length(entries) - 1
    "Showing #{first}–#{last} of #{total} events"
  end

  defp empty_description(assigns) do
    if filters_active?(assigns),
      do: "Try clearing the filters or broadening your search.",
      else: "Once tracked entities change, those events will appear here."
  end

  defp changes_caption([]), do: nil

  defp changes_caption(rows) do
    case length(rows) do
      1 -> "1 field changed"
      n -> "#{n} fields changed"
    end
  end
end
