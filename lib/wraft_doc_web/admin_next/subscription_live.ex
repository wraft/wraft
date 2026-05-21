defmodule WraftDocWeb.AdminNext.SubscriptionLive do
  @moduledoc """
  Subscription overview page for `/admin/subscriptions`.

  Surfaces revenue health — MRR / ARR with growth direction, status
  breakdown, monthly-vs-yearly split, upcoming renewals, and most recent
  new subscriptions — so sales/marketing teams can see at a glance whether
  the business is trending up or down.

  All numbers come from `WraftDoc.Admin.Metrics`. MRR is computed as
  committed MRR (active + trialing) since trialing customers are part of
  the pipeline sales teams care about.

  The page-level filter (`All / Monthly / Yearly`) re-scopes the renewals
  and new-subscription lists. Top stat cards always show the full picture
  so the headline numbers stay stable while drilling into a segment.
  """
  use Phoenix.LiveView

  import WraftDocWeb.AdminNext.UI

  alias WraftDoc.Admin.Metrics
  alias WraftDocWeb.AdminNext.UI.Tokens

  @filters [
    {"All", "all"},
    {"Monthly", "month"},
    {"Yearly", "year"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok, load(socket, :all)}
  end

  @impl true
  def handle_event("set-filter", %{"interval" => value}, socket) do
    {:noreply, load(socket, parse_filter(value))}
  end

  defp parse_filter("month"), do: :month
  defp parse_filter("year"), do: :year
  defp parse_filter(_), do: :all

  defp load(socket, filter) do
    overview = Metrics.revenue_overview()

    socket
    |> assign(:page_title, "Subscriptions")
    |> assign(:filter, filter)
    |> assign(:filters, @filters)
    |> assign(:revenue, overview)
    |> assign(:breakdown, %{monthly: overview.monthly, yearly: overview.yearly})
    |> assign(:sub_counts, Metrics.subscription_counts())
    |> assign(:trend, Metrics.subscription_trend(30))
    |> assign(:renewals, Metrics.upcoming_renewals(14, filter))
    |> assign(:recent_subs, Metrics.recent_subscriptions(8, filter))
    |> assign(:expired_subs, Metrics.expired_subscriptions(8, filter))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <WraftDocWeb.AdminNext.Layouts.app {assigns}>
      <div class="space-y-6">
        <.page_header
          title="Subscriptions"
          description="Recurring revenue, renewals, and pipeline at a glance."
        >
          <:eyebrow>Subscription & Billing</:eyebrow>
          <:status>
            <.status_pill variant={pipeline_variant(@trend)}>
              {pipeline_status(@trend)}
            </.status_pill>
          </:status>
          <:actions>
            <.button variant="ghost" navigate="/admin/plans">
              Manage plans
            </.button>
          </:actions>
        </.page_header>

        <%!-- Top stat cards: MRR, ARR, Active, Trialing --%>
        <section class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
          <.stat
            icon="hero-banknotes"
            label="MRR"
            value={format_money(@revenue.mrr, @revenue.currency)}
            footer={mrr_footer(@revenue)}
            accent="primary"
          />
          <.stat
            icon="hero-chart-bar"
            label="ARR"
            value={format_money(@revenue.arr, @revenue.currency)}
            footer="Annualised · MRR × 12"
            accent="success"
          />
          <.stat
            icon="hero-check-badge"
            label="Active subscriptions"
            value={@sub_counts.active}
            footer={"#{@trend.current} new in last 30d"}
            delta={@trend.delta_percent}
            accent="success"
          />
          <.stat
            icon="hero-sparkles"
            label="Trialing"
            value={@sub_counts.trialing}
            footer="In trial period"
            accent="warning"
          />
        </section>

        <%!-- Secondary stats: lifecycle / churn --%>
        <section class="grid grid-cols-2 gap-4 sm:grid-cols-4">
          <.mini_stat
            icon="hero-rectangle-stack"
            label="Total subscriptions"
            value={@sub_counts.total}
          />
          <.mini_stat
            icon="hero-x-circle"
            label="Expired"
            value={@sub_counts.expired}
          />
          <.mini_stat
            icon="hero-arrow-trending-down"
            label="Churn rate"
            value={churn_value(@sub_counts.churn_rate)}
          />
          <.mini_stat
            icon="hero-arrow-path"
            label="Renewals · 14d"
            value={length(@renewals)}
          />
        </section>

        <%!-- Monthly vs Yearly breakdown --%>
        <section>
          <.card
            title="Monthly vs Yearly"
            caption="Committed MRR split by billing interval"
          >
            <:header_actions>
              <span class="text-xs tabular-nums text-base-content/60">
                {@breakdown.monthly.count + @breakdown.yearly.count} subscriptions
              </span>
            </:header_actions>

            <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
              <.interval_panel
                icon="hero-calendar-days"
                label="Monthly"
                stats={@breakdown.monthly}
                share={interval_share(@breakdown, :monthly)}
                accent="primary"
              />
              <.interval_panel
                icon="hero-calendar"
                label="Yearly"
                stats={@breakdown.yearly}
                share={interval_share(@breakdown, :yearly)}
                accent="success"
                show_gross
              />
            </div>
          </.card>
        </section>

        <%!-- Multi-currency breakdown (only shown if more than one) --%>
        <section :if={length(@revenue.by_currency) > 1}>
          <.card title="Revenue by currency" caption="Committed MRR per currency">
            <div class="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3">
              <div
                :for={row <- @revenue.by_currency}
                class="flex items-center justify-between rounded-md border border-base-200 px-3 py-2"
              >
                <div>
                  <p class="text-xs uppercase tracking-wider text-base-content/60">
                    {row.currency}
                  </p>
                  <p class="ds-metric-value-sm">{format_money(row.mrr, row.currency)}</p>
                </div>
                <span class="text-xs tabular-nums text-base-content/60">
                  {row.count} {pluralise(row.count, "sub", "subs")}
                </span>
              </div>
            </div>
          </.card>
        </section>

        <%!-- Filter bar — scopes renewals + new subscriptions --%>
        <section class="flex items-center justify-between gap-3 rounded-md border border-base-200 bg-base-100 px-4 py-3">
          <div class="min-w-0">
            <p class="ds-section-title text-sm">Filter renewals & activity</p>
            <p class="ds-caption">
              {filter_description(@filter)}
            </p>
          </div>
          <.segmented
            current={filter_to_value(@filter)}
            options={@filters}
            event="set-filter"
            param="interval"
          />
        </section>

        <%!-- Renewals + New subscriptions + Recently expired --%>
        <section class="grid grid-cols-1 gap-4 lg:grid-cols-2">
          <.card
            title="Upcoming renewals"
            caption={renewals_caption(@filter)}
          >
            <:header_actions>
              <span class="text-xs tabular-nums text-base-content/60">
                {length(@renewals)} upcoming
              </span>
            </:header_actions>

            <%= if @renewals == [] do %>
              <.empty_state
                icon="hero-calendar"
                title="No renewals soon"
                description={renewals_empty(@filter)}
              />
            <% else %>
              <.data_table>
                <:col label="Customer" />
                <:col label="Plan" />
                <:col label="Bills" align="right" />
                <:col label="Amount" align="right" />
                <:row>
                  <tr :for={r <- @renewals}>
                    <td>
                      <div class="font-medium text-base-content">
                        {r.organisation_name || "—"}
                      </div>
                      <div class="font-mono text-xs text-base-content/60">
                        {r.subscriber_email || "—"}
                      </div>
                    </td>
                    <td class="text-base-content/80">
                      {r.plan_name || "—"}
                      <span class="text-xs text-base-content/50">
                        · {interval_label(r.billing_interval)}
                      </span>
                    </td>
                    <td class="text-right text-xs text-base-content/70">
                      {Tokens.format_date(r.next_bill_date)}
                    </td>
                    <td class="text-right font-medium tabular-nums">
                      {format_amount_string(r.amount, r.currency)}
                    </td>
                  </tr>
                </:row>
              </.data_table>
            <% end %>
          </.card>

          <.card
            title="New subscriptions"
            caption={recent_caption(@filter)}
          >
            <:header_actions>
              <span class="text-xs tabular-nums text-base-content/60">
                {@trend.current} in 30d
              </span>
            </:header_actions>

            <%= if @recent_subs == [] do %>
              <.empty_state
                icon="hero-sparkles"
                title="No subscriptions yet"
                description={recent_empty(@filter)}
              />
            <% else %>
              <ul class="ds-activity-list">
                <li :for={s <- @recent_subs} class="ds-activity-row">
                  <div class="min-w-0 flex-1">
                    <p class="truncate font-medium text-base-content">
                      {s.organisation_name || s.subscriber_email || "Subscription"}
                    </p>
                    <p class="truncate text-xs text-base-content/55">
                      {s.plan_name || "—"} · {interval_label(s.billing_interval)}
                    </p>
                  </div>
                  <div class="flex shrink-0 items-center gap-3">
                    <.badge variant={status_variant(s.status)}>{s.status || "—"}</.badge>
                    <span class="hidden text-xs text-base-content/50 sm:inline">
                      {Tokens.format_datetime(s.inserted_at)}
                    </span>
                  </div>
                </li>
              </ul>
            <% end %>
          </.card>
        </section>

        <%!-- Recently expired (churn) --%>
        <section>
          <.card
            title="Recently expired"
            caption={expired_caption(@filter)}
          >
            <:header_actions>
              <span class="text-xs tabular-nums text-base-content/60">
                {@sub_counts.expired} total expired
              </span>
            </:header_actions>

            <%= if @expired_subs == [] do %>
              <.empty_state
                icon="hero-x-circle"
                title="No expired subscriptions"
                description={expired_empty(@filter)}
              />
            <% else %>
              <.data_table>
                <:col label="Customer" />
                <:col label="Plan" />
                <:col label="Ended" align="right" />
                <:col label="Last amount" align="right" />
                <:row>
                  <tr :for={s <- @expired_subs}>
                    <td>
                      <div class="font-medium text-base-content">
                        {s.organisation_name || "—"}
                      </div>
                      <div class="font-mono text-xs text-base-content/60">
                        {s.subscriber_email || "—"}
                      </div>
                    </td>
                    <td class="text-base-content/80">
                      {s.plan_name || "—"}
                      <span class="text-xs text-base-content/50">
                        · {interval_label(s.billing_interval)}
                      </span>
                    </td>
                    <td class="text-right text-xs text-base-content/70">
                      {Tokens.format_datetime(s.end_date || s.updated_at)}
                    </td>
                    <td class="text-right font-medium tabular-nums">
                      {format_amount_string(s.amount, s.currency)}
                    </td>
                  </tr>
                </:row>
              </.data_table>
            <% end %>
          </.card>
        </section>
      </div>
    </WraftDocWeb.AdminNext.Layouts.app>
    """
  end

  # ----- Interval panel (private component) ---------------------------------

  attr :icon, :string, required: true
  attr :label, :string, required: true
  attr :stats, :map, required: true
  attr :share, :integer, required: true, doc: "Share of total MRR as a percentage 0..100."
  attr :accent, :string, default: "primary"
  attr :show_gross, :boolean, default: false

  defp interval_panel(assigns) do
    ~H"""
    <div class="rounded-md border border-base-200 bg-base-100 p-4">
      <div class="flex items-center justify-between">
        <div class="flex items-center gap-2 text-base-content/70">
          <Backpex.HTML.CoreComponents.icon name={@icon} class="size-4" />
          <span class="ds-metric-label">{@label}</span>
        </div>
        <span class="text-xs tabular-nums text-base-content/60">
          {@stats.count} {pluralise(@stats.count, "sub", "subs")}
        </span>
      </div>

      <div class="mt-3 flex items-baseline gap-2">
        <p class="ds-metric-value-sm">{format_money(@stats.mrr, @stats.currency)}</p>
        <span class="text-xs text-base-content/60">MRR</span>
      </div>

      <div :if={@show_gross} class="mt-1 text-xs text-base-content/60">
        Gross annual: {format_money(@stats.gross, @stats.currency)}
      </div>

      <div class="mt-3">
        <div class="mb-1 flex items-center justify-between text-xs">
          <span class="text-base-content/60">Share of MRR</span>
          <span class="tabular-nums text-base-content/70">{@share}%</span>
        </div>
        <div class="ds-progress-track">
          <div
            class={["ds-progress-fill", Tokens.progress_class(@accent)]}
            style={"width: #{@share}%"}
          />
        </div>
      </div>
    </div>
    """
  end

  # ----- Local helpers ------------------------------------------------------

  defp pipeline_variant(%{delta_percent: d}) when is_number(d) and d > 0, do: "success"
  defp pipeline_variant(%{delta_percent: d}) when is_number(d) and d < 0, do: "error"
  defp pipeline_variant(_), do: "neutral"

  defp pipeline_status(%{delta_percent: d}) when is_number(d) and d > 0, do: "Pipeline up"
  defp pipeline_status(%{delta_percent: d}) when is_number(d) and d < 0, do: "Pipeline down"
  defp pipeline_status(_), do: "Pipeline steady"

  defp mrr_footer(%{by_currency: []}), do: "No active subscriptions"
  defp mrr_footer(%{by_currency: [_only]}), do: "Committed MRR · active + trialing"
  defp mrr_footer(%{by_currency: list}), do: "Primary currency · #{length(list)} total"

  defp interval_share(breakdown, key) do
    total = breakdown.monthly.mrr + breakdown.yearly.mrr
    value = Map.fetch!(breakdown, key).mrr

    if total > 0 do
      round(value / total * 100)
    else
      0
    end
  end

  defp filter_to_value(:all), do: "all"
  defp filter_to_value(:month), do: "month"
  defp filter_to_value(:year), do: "year"

  defp filter_description(:all),
    do: "Showing all billing intervals."

  defp filter_description(:month),
    do: "Showing monthly-billed subscriptions only."

  defp filter_description(:year),
    do: "Showing yearly-billed subscriptions only."

  defp renewals_caption(:all), do: "Subscriptions billing in the next 14 days"
  defp renewals_caption(:month), do: "Monthly subscriptions billing in the next 14 days"
  defp renewals_caption(:year), do: "Yearly subscriptions billing in the next 14 days"

  defp renewals_empty(:all),
    do: "No active subscriptions are scheduled to bill in the next 14 days."

  defp renewals_empty(:month),
    do: "No monthly subscriptions are billing in the next 14 days."

  defp renewals_empty(:year),
    do: "No yearly subscriptions are billing in the next 14 days."

  defp recent_caption(:all), do: "Most recently created"
  defp recent_caption(:month), do: "Most recent monthly subscriptions"
  defp recent_caption(:year), do: "Most recent yearly subscriptions"

  defp recent_empty(:all),
    do: "New paid or trialing subscriptions will appear here."

  defp recent_empty(:month),
    do: "No monthly subscriptions yet."

  defp recent_empty(:year),
    do: "No yearly subscriptions yet."

  defp expired_caption(:all), do: "Subscriptions that have churned, most recent first"
  defp expired_caption(:month), do: "Monthly subscriptions that have expired, most recent first"
  defp expired_caption(:year), do: "Yearly subscriptions that have expired, most recent first"

  defp expired_empty(:all),
    do: "No subscriptions have expired yet."

  defp expired_empty(:month),
    do: "No monthly subscriptions have expired."

  defp expired_empty(:year),
    do: "No yearly subscriptions have expired."

  defp churn_value(nil), do: "—"
  defp churn_value(rate) when is_number(rate), do: "#{rate}%"

  defp format_money(amount, currency) when is_number(amount) do
    "#{currency_symbol(currency)}#{format_number(amount)}"
  end

  defp format_money(_, currency), do: "#{currency_symbol(currency)}0"

  defp format_amount_string(amount, currency) when is_binary(amount) and amount != "" do
    case Float.parse(amount) do
      {value, _} -> "#{currency_symbol(currency)}#{format_number(value)}"
      :error -> amount
    end
  end

  defp format_amount_string(_, _), do: "—"

  defp format_number(n) when is_number(n) do
    n
    |> Float.round(2)
    |> :erlang.float_to_binary(decimals: 2)
    |> thousands()
  end

  defp thousands(str) do
    [int_part | rest] = String.split(str, ".")
    grouped = int_part |> String.reverse() |> chunk_3() |> Enum.join(",") |> String.reverse()
    Enum.join([grouped | rest], ".")
  end

  defp chunk_3(""), do: []
  defp chunk_3(str) when byte_size(str) <= 3, do: [str]

  defp chunk_3(str) do
    {head, tail} = String.split_at(str, 3)
    [head | chunk_3(tail)]
  end

  # Lowercase / mixed-case currency codes from the DB still resolve to the
  # right symbol — the metrics layer normalises but defenders against
  # untrusted input that flows in directly (e.g. legacy rows).
  defp currency_symbol(code) when is_binary(code), do: symbol_for(String.upcase(code))
  defp currency_symbol(_), do: "$"

  defp symbol_for("USD"), do: "$"
  defp symbol_for("EUR"), do: "€"
  defp symbol_for("GBP"), do: "£"
  defp symbol_for("INR"), do: "₹"
  defp symbol_for(code), do: "#{code} "

  defp interval_label(:month), do: "Monthly"
  defp interval_label(:year), do: "Yearly"
  defp interval_label(:custom), do: "Custom"
  defp interval_label(_), do: "—"

  defp status_variant("active"), do: "success"
  defp status_variant("trialing"), do: "warning"
  defp status_variant("expired"), do: "error"
  defp status_variant("canceled"), do: "error"
  defp status_variant(_), do: "neutral"

  defp pluralise(1, singular, _plural), do: singular
  defp pluralise(_, _singular, plural), do: plural
end
