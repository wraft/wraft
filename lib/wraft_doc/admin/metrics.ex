defmodule WraftDoc.Admin.Metrics do
  @moduledoc """
  Aggregate queries that power the Backpex admin dashboard at `/admin`.

  These were previously inlined in the Kaffy admin modules (User widget,
  Organisation widget, WaitingList widget) plus the now-removed
  `WraftDoc.Kaffy.CustomDataAdmin` helper. Consolidated here so the
  dashboard LiveView has one place to load from.
  """
  import Ecto.Query

  alias WraftDoc.Account.User
  alias WraftDoc.AdminWebhooks.AdminWebhook
  alias WraftDoc.AdminWebhooks.AdminWebhookLog
  alias WraftDoc.Billing.Subscription
  alias WraftDoc.ContentTypes.ContentType
  alias WraftDoc.DataTemplates.DataTemplate
  alias WraftDoc.Documents.Instance
  alias WraftDoc.Enterprise.Organisation
  alias WraftDoc.Enterprise.Plan
  alias WraftDoc.InternalUsers.InternalUser
  alias WraftDoc.Repo
  alias WraftDoc.WaitingLists.WaitingList

  @doc """
  Returns the headline counts in a single map. Each query is cheap (a single
  `count(id)`); no batching needed at this scale.
  """
  @spec counts() :: %{
          users: integer(),
          organisations: integer(),
          internal_users: integer(),
          pending_waiting_list: integer(),
          active_webhooks: integer(),
          rejected_waiting_list: integer(),
          approved_waiting_list: integer()
        }
  def counts do
    %{
      users: Repo.aggregate(from(u in User), :count, :id),
      organisations:
        Repo.aggregate(from(o in Organisation, where: o.name != "Personal"), :count, :id),
      internal_users: Repo.aggregate(from(i in InternalUser), :count, :id),
      pending_waiting_list:
        Repo.aggregate(from(w in WaitingList, where: w.status == :pending), :count, :id),
      approved_waiting_list:
        Repo.aggregate(from(w in WaitingList, where: w.status == :approved), :count, :id),
      rejected_waiting_list:
        Repo.aggregate(from(w in WaitingList, where: w.status == :rejected), :count, :id),
      active_webhooks:
        Repo.aggregate(from(a in AdminWebhook, where: a.is_active == true), :count, :id)
    }
  end

  @doc """
  Returns waiting list signups grouped by day for the last 30 days, ordered
  from oldest to newest. Days with zero signups are filled in so the chart
  has a complete x-axis.
  """
  @spec daily_waiting_list_signups(non_neg_integer()) :: [%{date: Date.t(), count: integer()}]
  def daily_waiting_list_signups(days_back \\ 30) do
    today = Date.utc_today()
    from_date = Date.add(today, -days_back)

    {:ok, from_naive} = NaiveDateTime.new(from_date, ~T[00:00:00])

    query =
      from(w in WaitingList,
        where: w.inserted_at >= ^from_naive,
        group_by: fragment("date(?)", w.inserted_at),
        select: {fragment("date(?)::text", w.inserted_at), count(w.id)}
      )

    grouped =
      query
      |> Repo.all()
      |> Map.new(fn {date_str, count} -> {Date.from_iso8601!(date_str), count} end)

    for offset <- 0..days_back do
      date = Date.add(from_date, offset)
      %{date: date, count: Map.get(grouped, date, 0)}
    end
  end

  @doc """
  Returns the 10 most recent waiting list signups, ordered newest first.
  Useful for an "Activity" panel on the dashboard.
  """
  @spec recent_waiting_list(non_neg_integer()) :: [WaitingList.t()]
  def recent_waiting_list(limit \\ 10) do
    Repo.all(
      from(w in WaitingList,
        order_by: [desc: w.inserted_at],
        limit: ^limit
      )
    )
  end

  @doc """
  Document-side counts: instances (content rows), content types, data templates.
  """
  @spec document_counts() :: %{
          instances: integer(),
          content_types: integer(),
          data_templates: integer()
        }
  def document_counts do
    %{
      instances: Repo.aggregate(from(i in Instance), :count, :id),
      content_types: Repo.aggregate(from(c in ContentType), :count, :id),
      data_templates: Repo.aggregate(from(d in DataTemplate), :count, :id)
    }
  end

  @doc """
  Webhook delivery health over the last `hours_back` hours (default 24h):
  total attempts, successes, failures, and the median + p95 execution time.
  """
  @spec webhook_health(non_neg_integer()) :: %{
          total: integer(),
          success: integer(),
          failed: integer(),
          success_rate: float()
        }
  def webhook_health(hours_back \\ 24) do
    since = DateTime.add(DateTime.utc_now(), -hours_back * 3600, :second)

    total =
      Repo.aggregate(from(l in AdminWebhookLog, where: l.triggered_at >= ^since), :count, :id)

    success =
      Repo.aggregate(
        from(l in AdminWebhookLog,
          where: l.triggered_at >= ^since and l.success == true
        ),
        :count,
        :id
      )

    failed = total - success

    success_rate =
      case total do
        0 -> 0.0
        n -> Float.round(success / n * 100, 1)
      end

    %{total: total, success: success, failed: failed, success_rate: success_rate}
  end

  @doc """
  Last `limit` failed webhook deliveries, newest first. Useful for surfacing
  recent integration issues on the dashboard.
  """
  @spec recent_webhook_failures(non_neg_integer()) :: [AdminWebhookLog.t()]
  def recent_webhook_failures(limit \\ 5) do
    Repo.all(
      from(l in AdminWebhookLog,
        where: l.success == false,
        order_by: [desc: l.triggered_at],
        limit: ^limit,
        preload: [:webhook]
      )
    )
  end

  @doc """
  Last `limit` users who signed in, newest first. Users who have never
  signed in are excluded.
  """
  @spec recent_logins(non_neg_integer()) :: [User.t()]
  def recent_logins(limit \\ 10) do
    Repo.all(
      from(u in User,
        where: not is_nil(u.signed_in_at),
        order_by: [desc: u.signed_in_at],
        limit: ^limit
      )
    )
  end

  @doc """
  Plan distribution — counts active subscriptions per individual plan.
  Active = subscription status in ("active", "trialing"). Plans without any
  active subscription do not appear. Powers the bottom-right panel of the
  dashboard.
  """
  @spec plan_distribution() :: [
          %{
            plan_id: Ecto.UUID.t(),
            name: String.t() | nil,
            billing_interval: atom() | nil,
            type: atom() | nil,
            count: integer()
          }
        ]
  def plan_distribution do
    query =
      from(s in Subscription,
        join: p in Plan,
        on: p.id == s.plan_id,
        where: s.status in ["active", "trialing"],
        group_by: [p.id, p.name, p.billing_interval, p.type],
        select: %{
          plan_id: p.id,
          name: p.name,
          billing_interval: p.billing_interval,
          type: p.type,
          count: count(s.id)
        }
      )

    query
    |> Repo.all()
    |> Enum.sort_by(& &1.count, :desc)
  end

  @doc """
  Subscription counts grouped by status, plus a churn rate (expired ÷ total).
  Powers the stat cards on the Subscriptions page.

  `churn_rate` is `nil` when there are no subscriptions at all (avoids a
  meaningless "0% churn — no customers" reading on an empty system).
  """
  @spec subscription_counts() :: %{
          active: integer(),
          trialing: integer(),
          expired: integer(),
          total: integer(),
          churn_rate: float() | nil
        }
  def subscription_counts do
    query =
      from(s in Subscription,
        group_by: s.status,
        select: {s.status, count(s.id)}
      )

    rows =
      query
      |> Repo.all()
      |> Map.new()

    active = Map.get(rows, "active", 0)
    trialing = Map.get(rows, "trialing", 0)
    expired = Map.get(rows, "expired", 0)
    total = Enum.sum(Map.values(rows))

    churn_rate =
      if total > 0 do
        Float.round(expired / total * 100, 1)
      end

    %{
      active: active,
      trialing: trialing,
      expired: expired,
      total: total,
      churn_rate: churn_rate
    }
  end

  @doc """
  Revenue overview — Monthly Recurring Revenue (MRR), Annual Recurring
  Revenue (ARR = MRR × 12), per-currency breakdown, and a monthly-vs-yearly
  split. All in one DB roundtrip.

  Computed across **active + trialing** subscriptions (committed MRR — what
  sales/marketing teams typically watch).

  MRR contribution rules:
  - `:month` billing → `next_bill_amount` contributes directly.
  - `:year` billing → `next_bill_amount / 12` contributes.
  - `:custom` billing → excluded (enterprise contracts on bespoke cadence).

  "Primary currency" is the most frequent currency across qualifying subs
  (count-based, not revenue-based) — the same definition used inside the
  interval breakdown so the headline and the panels agree.
  """
  @spec revenue_overview() :: %{
          mrr: float(),
          arr: float(),
          currency: String.t(),
          by_currency: [%{currency: String.t(), mrr: float(), arr: float(), count: integer()}],
          monthly: %{count: integer(), gross: float(), mrr: float(), currency: String.t()},
          yearly: %{count: integer(), gross: float(), mrr: float(), currency: String.t()}
        }
  def revenue_overview do
    rows = active_billable_rows()

    %{
      mrr: total_mrr,
      arr: total_arr,
      currency: primary,
      by_currency: by_currency
    } = summarise(rows)

    %{
      mrr: total_mrr,
      arr: total_arr,
      currency: primary,
      by_currency: by_currency,
      monthly: interval_stats(rows, :month),
      yearly: interval_stats(rows, :year)
    }
  end

  defp active_billable_rows do
    query =
      from(s in Subscription,
        join: p in Plan,
        on: p.id == s.plan_id,
        where: s.status in ["active", "trialing"],
        where: p.billing_interval in [:month, :year],
        select: %{
          amount: s.next_bill_amount,
          currency: s.currency,
          billing_interval: p.billing_interval
        }
      )

    Repo.all(query)
  end

  defp summarise(rows) do
    by_currency =
      rows
      |> Enum.group_by(&normalise_currency(&1.currency))
      |> Enum.map(fn {currency, subs} ->
        mrr =
          subs
          |> Enum.reduce(0.0, fn sub, acc -> acc + mrr_contribution(sub) end)
          |> Float.round(2)

        %{
          currency: currency,
          mrr: mrr,
          arr: Float.round(mrr * 12, 2),
          count: length(subs)
        }
      end)
      |> Enum.sort_by(& &1.count, :desc)

    primary = primary_currency(rows)
    headline = Enum.find(by_currency, &(&1.currency == primary))

    case headline do
      nil ->
        %{mrr: 0.0, arr: 0.0, currency: "USD", by_currency: []}

      %{mrr: mrr, arr: arr} ->
        %{mrr: mrr, arr: arr, currency: primary, by_currency: by_currency}
    end
  end

  defp mrr_contribution(%{amount: amount, billing_interval: interval}) do
    case parse_amount(amount) do
      value when value <= 0.0 -> 0.0
      value when interval == :month -> value
      value when interval == :year -> value / 12
      _ -> 0.0
    end
  end

  defp interval_stats(rows, interval) do
    matching = Enum.filter(rows, &(&1.billing_interval == interval))

    gross =
      matching
      |> Enum.reduce(0.0, fn row, acc -> acc + parse_amount(row.amount) end)
      |> Float.round(2)

    mrr =
      case interval do
        :month -> gross
        :year -> Float.round(gross / 12, 2)
      end

    %{
      count: length(matching),
      gross: gross,
      mrr: mrr,
      currency: primary_currency(matching)
    }
  end

  defp primary_currency([]), do: "USD"

  defp primary_currency(rows) do
    rows
    |> Enum.map(&normalise_currency(&1.currency))
    |> Enum.frequencies()
    |> Enum.max_by(fn {_currency, count} -> count end, fn -> {"USD", 0} end)
    |> elem(0)
  end

  defp parse_amount(nil), do: 0.0
  defp parse_amount(""), do: 0.0

  defp parse_amount(str) when is_binary(str) do
    case Float.parse(str) do
      {value, _rest} -> value
      :error -> 0.0
    end
  end

  defp parse_amount(value) when is_number(value), do: value * 1.0
  defp parse_amount(_), do: 0.0

  defp normalise_currency(nil), do: "USD"
  defp normalise_currency(""), do: "USD"
  defp normalise_currency(code) when is_binary(code), do: String.upcase(code)

  @doc """
  New-subscription velocity. Counts subscriptions **created** in the current
  window vs the prior window of the same length (default 30 days) and
  returns a signed delta percentage.

  No status filter — this is the raw new-business signal. A sub that was
  created and then expired in the same window still counts, since the
  intent is to measure how fast new business arrives, not how much
  survives. Survival/churn is reported separately via `subscription_counts/0`.
  """
  @spec subscription_trend(non_neg_integer()) :: %{
          current: integer(),
          previous: integer(),
          delta_percent: float() | nil
        }
  def subscription_trend(days \\ 30) do
    now = DateTime.utc_now()
    current_from = DateTime.add(now, -days * 86_400, :second)
    previous_from = DateTime.add(now, -2 * days * 86_400, :second)

    current =
      Repo.aggregate(
        from(s in Subscription, where: s.inserted_at >= ^current_from),
        :count,
        :id
      )

    previous =
      Repo.aggregate(
        from(s in Subscription,
          where: s.inserted_at >= ^previous_from and s.inserted_at < ^current_from
        ),
        :count,
        :id
      )

    delta =
      cond do
        previous == 0 and current == 0 -> 0.0
        previous == 0 -> 100.0
        true -> Float.round((current - previous) / previous * 100, 1)
      end

    %{current: current, previous: previous, delta_percent: delta}
  end

  @doc """
  Subscriptions with `next_bill_date` within the next `days` calendar days
  (default 14). Ordered by soonest first.

  `interval` filters by plan billing interval: `:all` (default), `:month`,
  or `:year`. Powers the renewals card with the page-level Monthly/Yearly
  filter.
  """
  @spec upcoming_renewals(non_neg_integer(), :all | :month | :year) :: [
          %{
            id: Ecto.UUID.t(),
            subscriber_email: String.t() | nil,
            organisation_name: String.t() | nil,
            plan_name: String.t() | nil,
            billing_interval: atom() | nil,
            next_bill_date: Date.t() | nil,
            amount: String.t() | nil,
            currency: String.t() | nil,
            status: String.t() | nil
          }
        ]
  def upcoming_renewals(days \\ 14, interval \\ :all) do
    today = Date.utc_today()
    horizon = Date.add(today, days)

    query =
      from(s in Subscription,
        join: p in Plan,
        on: p.id == s.plan_id,
        left_join: u in User,
        on: u.id == s.subscriber_id,
        left_join: o in Organisation,
        on: o.id == s.organisation_id,
        where: s.status in ["active", "trialing"],
        where: not is_nil(s.next_bill_date),
        where: s.next_bill_date >= ^today and s.next_bill_date <= ^horizon,
        order_by: [asc: s.next_bill_date],
        select: %{
          id: s.id,
          subscriber_email: u.email,
          organisation_name: o.name,
          plan_name: p.name,
          billing_interval: p.billing_interval,
          next_bill_date: s.next_bill_date,
          amount: s.next_bill_amount,
          currency: s.currency,
          status: s.status
        }
      )

    query
    |> filter_by_interval(interval)
    |> Repo.all()
  end

  @doc """
  Most recent subscriptions, ordered by `inserted_at` desc. Default limit 8.

  `interval` filters by plan billing interval: `:all` (default), `:month`,
  or `:year`.
  """
  @spec recent_subscriptions(non_neg_integer(), :all | :month | :year) :: [
          %{
            id: Ecto.UUID.t(),
            subscriber_email: String.t() | nil,
            organisation_name: String.t() | nil,
            plan_name: String.t() | nil,
            billing_interval: atom() | nil,
            status: String.t() | nil,
            amount: String.t() | nil,
            currency: String.t() | nil,
            inserted_at: NaiveDateTime.t() | DateTime.t() | nil
          }
        ]
  def recent_subscriptions(limit \\ 8, interval \\ :all) do
    query =
      from(s in Subscription,
        join: p in Plan,
        on: p.id == s.plan_id,
        left_join: u in User,
        on: u.id == s.subscriber_id,
        left_join: o in Organisation,
        on: o.id == s.organisation_id,
        order_by: [desc: s.inserted_at],
        limit: ^limit,
        select: %{
          id: s.id,
          subscriber_email: u.email,
          organisation_name: o.name,
          plan_name: p.name,
          billing_interval: p.billing_interval,
          status: s.status,
          amount: s.next_bill_amount,
          currency: s.currency,
          inserted_at: s.inserted_at
        }
      )

    query
    |> filter_by_interval(interval)
    |> Repo.all()
  end

  @doc """
  Most recently expired subscriptions, ordered by `end_date` desc (falling
  back to `updated_at`). Default limit 8.

  Used by the "Recently expired" card on the Subscriptions page — gives
  sales/CS a quick view of churn so they can follow up. Honours the
  page-level Monthly/Yearly interval filter.
  """
  @spec expired_subscriptions(non_neg_integer(), :all | :month | :year) :: [
          %{
            id: Ecto.UUID.t(),
            subscriber_email: String.t() | nil,
            organisation_name: String.t() | nil,
            plan_name: String.t() | nil,
            billing_interval: atom() | nil,
            status: String.t() | nil,
            amount: String.t() | nil,
            currency: String.t() | nil,
            end_date: DateTime.t() | nil,
            updated_at: NaiveDateTime.t() | DateTime.t() | nil
          }
        ]
  def expired_subscriptions(limit \\ 8, interval \\ :all) do
    query =
      from(s in Subscription,
        join: p in Plan,
        on: p.id == s.plan_id,
        left_join: u in User,
        on: u.id == s.subscriber_id,
        left_join: o in Organisation,
        on: o.id == s.organisation_id,
        where: s.status == "expired",
        order_by: [desc: coalesce(s.end_date, s.updated_at)],
        limit: ^limit,
        select: %{
          id: s.id,
          subscriber_email: u.email,
          organisation_name: o.name,
          plan_name: p.name,
          billing_interval: p.billing_interval,
          status: s.status,
          amount: s.next_bill_amount,
          currency: s.currency,
          end_date: s.end_date,
          updated_at: s.updated_at
        }
      )

    query
    |> filter_by_interval(interval)
    |> Repo.all()
  end

  @doc """
  Trend delta as a signed percentage. Compares the count in the current
  window vs the prior window of the same length. Used by stat-card badges.
  Returns `nil` if there's nothing to compare against.
  """
  @spec signup_trend(non_neg_integer()) :: %{
          current: integer(),
          previous: integer(),
          delta_percent: float() | nil
        }
  def signup_trend(days \\ 7) do
    now_naive = NaiveDateTime.utc_now()
    current_from = NaiveDateTime.add(now_naive, -days * 86_400, :second)
    previous_from = NaiveDateTime.add(now_naive, -2 * days * 86_400, :second)

    current =
      Repo.aggregate(
        from(u in User, where: u.inserted_at >= ^current_from),
        :count,
        :id
      )

    previous =
      Repo.aggregate(
        from(u in User,
          where: u.inserted_at >= ^previous_from and u.inserted_at < ^current_from
        ),
        :count,
        :id
      )

    delta =
      cond do
        previous == 0 and current == 0 -> 0.0
        previous == 0 -> 100.0
        true -> Float.round((current - previous) / previous * 100, 1)
      end

    %{current: current, previous: previous, delta_percent: delta}
  end

  @doc """
  Daily user signups for the last `days_back` days (default 30), with empty
  days filled to zero. Mirrors `daily_waiting_list_signups/1`.
  """
  @spec daily_user_signups(non_neg_integer()) :: [%{date: Date.t(), count: integer()}]
  def daily_user_signups(days_back \\ 30) do
    today = Date.utc_today()
    from_date = Date.add(today, -days_back)

    {:ok, from_naive} = NaiveDateTime.new(from_date, ~T[00:00:00])

    query =
      from(u in User,
        where: u.inserted_at >= ^from_naive,
        group_by: fragment("date(?)", u.inserted_at),
        select: {fragment("date(?)::text", u.inserted_at), count(u.id)}
      )

    grouped =
      query
      |> Repo.all()
      |> Map.new(fn {date_str, count} -> {Date.from_iso8601!(date_str), count} end)

    for offset <- 0..days_back do
      date = Date.add(from_date, offset)
      %{date: date, count: Map.get(grouped, date, 0)}
    end
  end

  # ----- Shared private helpers --------------------------------------------

  # Composable filter for queries that already join `Subscription` (s) and
  # `Plan` (p). Lets call sites add an `interval` filter without copying the
  # `from([s, p] in query, ...)` boilerplate.
  defp filter_by_interval(query, :all), do: query

  defp filter_by_interval(query, interval) when interval in [:month, :year] do
    from([s, p] in query, where: p.billing_interval == ^interval)
  end
end
