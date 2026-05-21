defmodule WraftDocWeb.AdminNext.HomeLive do
  @moduledoc """
  Dashboard LiveView for `/admin`.

  Composes design-system primitives (`WraftDocWeb.AdminNext.UI`) from
  metrics in `WraftDoc.Admin.Metrics`. All charts are SVG/CSS — no JS
  dependency.
  """
  use Phoenix.LiveView

  import WraftDocWeb.AdminNext.UI

  alias WraftDoc.Admin.Metrics
  alias WraftDocWeb.AdminNext.UI.Tokens

  @ranges [
    {"7D", 7},
    {"30D", 30},
    {"90D", 90}
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok, load(socket, 30)}
  end

  @impl true
  def handle_event("set-range", %{"days" => days}, socket) do
    {:noreply, load(socket, String.to_integer(days))}
  end

  defp load(socket, days) do
    socket
    |> assign(:page_title, "Dashboard")
    |> assign(:range_days, days)
    |> assign(:ranges, @ranges)
    |> assign(:counts, Metrics.counts())
    |> assign(:documents, Metrics.document_counts())
    |> assign(:webhook_health, Metrics.webhook_health(24))
    |> assign(:user_signups, Metrics.daily_user_signups(days))
    |> assign(:waiting_signups, Metrics.daily_waiting_list_signups(days))
    |> assign(:trend, Metrics.signup_trend(7))
    |> assign(:recent, Metrics.recent_waiting_list(8))
    |> assign(:recent_logins, Metrics.recent_logins(5))
    |> assign(:plan_dist, Metrics.plan_distribution())
  end

  @impl true
  def render(assigns) do
    ~H"""
    <WraftDocWeb.AdminNext.Layouts.app {assigns}>
      <div class="space-y-6">
        <.page_header
          title="Dashboard"
          description="Real-time metrics and growth health for your workspace."
        >
          <:eyebrow>Overview</:eyebrow>
          <:status>
            <.status_pill variant={Tokens.webhook_variant(@webhook_health)}>
              {Tokens.webhook_label(@webhook_health)}
            </.status_pill>
          </:status>
          <:actions>
            <.button variant="primary" icon="hero-plus" navigate="/admin/users">
              Invite users
            </.button>
          </:actions>
        </.page_header>

        <%!-- Top stat cards with sparklines --%>
        <section class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
          <.stat
            icon="hero-clock"
            label="Waiting users"
            value={@counts.pending_waiting_list}
            footer="pending approval"
            accent="warning"
          >
            <:trail>
              <.sparkline series={Enum.map(@waiting_signups, & &1.count)} accent="warning" />
            </:trail>
          </.stat>

          <.stat
            icon="hero-users"
            label="Active users"
            value={@counts.users}
            footer={"#{@trend.current} new this week"}
            delta={@trend.delta_percent}
            accent="primary"
          >
            <:trail>
              <.sparkline series={Enum.map(@user_signups, & &1.count)} accent="primary" />
            </:trail>
          </.stat>

          <.stat
            icon="hero-building-office-2"
            label="Organisations"
            value={@counts.organisations}
            footer="across the platform"
            accent="success"
          >
            <:trail>
              <.sparkline series={Enum.map(@user_signups, & &1.count)} accent="success" />
            </:trail>
          </.stat>

          <.stat
            icon="hero-signal"
            label="Webhook health"
            value={"#{@webhook_health.success_rate}%"}
            footer={"#{@webhook_health.success}/#{@webhook_health.total} ok · last 24h"}
            accent={Tokens.webhook_variant(@webhook_health)}
          >
            <:trail>
              <.sparkline
                series={[@webhook_health.success, @webhook_health.failed]}
                accent={Tokens.webhook_variant(@webhook_health)}
              />
            </:trail>
          </.stat>
        </section>

        <%!-- Secondary stat row --%>
        <section class="grid grid-cols-2 gap-4 sm:grid-cols-4">
          <.mini_stat icon="hero-document-text" label="Documents" value={@documents.instances} />
          <.mini_stat
            icon="hero-rectangle-group"
            label="Content types"
            value={@documents.content_types}
          />
          <.mini_stat
            icon="hero-document-duplicate"
            label="Data templates"
            value={@documents.data_templates}
          />
          <.mini_stat
            icon="hero-shield-check"
            label="Internal users"
            value={@counts.internal_users}
          />
        </section>

        <%!-- Main chart + plan distribution --%>
        <section class="grid grid-cols-1 gap-4 lg:grid-cols-3">
          <.card
            class="lg:col-span-2"
            title="User registrations"
            caption={chart_caption(@user_signups, @range_days, @trend)}
          >
            <:header_actions>
              <.segmented
                current={@range_days}
                options={@ranges}
                event="set-range"
                param="days"
              />
            </:header_actions>
            <.area_chart series={@user_signups} accent="primary" height={220} />
          </.card>

          <.card
            title="Plan distribution"
            caption="Active subscriptions per plan"
          >
            <:header_actions>
              <span class="text-xs tabular-nums text-base-content/60">
                {Enum.sum(Enum.map(@plan_dist, & &1.count))} total
              </span>
            </:header_actions>

            <%= if @plan_dist == [] do %>
              <.empty_state
                icon="hero-credit-card"
                title="No active subscriptions"
                description="Subscriptions will appear here, grouped by plan."
              />
            <% else %>
              <div class="space-y-3">
                <.progress_row
                  :for={row <- @plan_dist}
                  label={plan_row_label(row)}
                  count={row.count}
                  max={max_plan_count(@plan_dist)}
                />
              </div>
            <% end %>
          </.card>
        </section>

        <%!-- Activity row --%>
        <section class="grid grid-cols-1 gap-4 lg:grid-cols-2">
          <.card
            title="Recent logins"
          >
            <:header_actions>
              <.button variant="ghost" size="sm" navigate="/admin/users">
                View all →
              </.button>
            </:header_actions>

            <%= if @recent_logins == [] do %>
              <.empty_state
                icon="hero-user-circle"
                title="No recent logins"
                description="Users who sign in will appear here, most recent first."
              />
            <% else %>
              <.data_table>
                <:col label="User" />
                <:col label="Email" />
                <:col label="Last login" align="right" />
                <:row>
                  <tr :for={user <- @recent_logins}>
                    <td class="font-medium text-base-content">{user.name}</td>
                    <td class="font-mono text-xs text-base-content/70">{user.email}</td>
                    <td class="text-right text-xs text-base-content/60">
                      {Tokens.format_datetime(user.signed_in_at)}
                    </td>
                  </tr>
                </:row>
              </.data_table>
            <% end %>
          </.card>

          <.card title="Latest access requests">
            <:header_actions>
              <.button variant="ghost" size="sm" navigate="/admin/waiting-list">
                View all →
              </.button>
            </:header_actions>

            <%= if @recent == [] do %>
              <.empty_state
                icon="hero-clock"
                title="No waiting list entries"
                description="Access requests submitted from the marketing site appear here."
              />
            <% else %>
              <ul class="ds-activity-list">
                <li :for={w <- @recent} class="ds-activity-row">
                  <div class="min-w-0 flex-1">
                    <p class="truncate font-medium text-base-content">
                      {w.first_name} {w.last_name}
                    </p>
                    <p class="truncate font-mono text-xs text-base-content/55">{w.email}</p>
                  </div>
                  <div class="flex shrink-0 items-center gap-3">
                    <.badge variant={Tokens.status_variant(w.status)}>{w.status}</.badge>
                    <span class="hidden text-xs text-base-content/50 sm:inline">
                      {Tokens.format_datetime(w.inserted_at)}
                    </span>
                  </div>
                </li>
              </ul>
            <% end %>
          </.card>
        </section>
      </div>
    </WraftDocWeb.AdminNext.Layouts.app>
    """
  end

  # ----- Local helpers ------------------------------------------------------

  defp chart_caption(signups, range_days, trend) do
    total = Enum.sum(Enum.map(signups, & &1.count))
    base = "#{total} total · last #{range_days} days"

    case trend.delta_percent do
      d when is_number(d) -> "#{base} · #{Tokens.format_delta(d)} vs prev period"
      _ -> base
    end
  end

  defp max_plan_count([]), do: 1
  defp max_plan_count(list), do: list |> Enum.map(& &1.count) |> Enum.max(fn -> 1 end) |> max(1)

  defp plan_row_label(%{name: name} = row) when is_binary(name) and name != "" do
    case row.billing_interval do
      :month -> "#{name} · Monthly"
      :year -> "#{name} · Yearly"
      :custom -> "#{name} · Custom"
      _ -> name
    end
  end

  defp plan_row_label(row), do: Tokens.plan_label(row.type)
end
