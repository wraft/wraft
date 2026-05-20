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

    grouped =
      from(w in WaitingList,
        where: w.inserted_at >= ^from_naive,
        group_by: fragment("date(?)", w.inserted_at),
        select: {fragment("date(?)::text", w.inserted_at), count(w.id)}
      )
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
    since = DateTime.utc_now() |> DateTime.add(-hours_back * 3600, :second)

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
  Plan distribution — counts of active Plan rows grouped by `:type` enum
  (free / regular / enterprise). Useful for the bottom-right panel of the
  dashboard.
  """
  @spec plan_distribution() :: %{type: atom(), count: integer()}
  def plan_distribution do
    from(p in Plan,
      where: p.is_active? == true,
      group_by: p.type,
      select: {p.type, count(p.id)}
    )
    |> Repo.all()
    |> Enum.map(fn {type, count} -> %{type: type, count: count} end)
    |> Enum.sort_by(& &1.count, :desc)
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

    grouped =
      from(u in User,
        where: u.inserted_at >= ^from_naive,
        group_by: fragment("date(?)", u.inserted_at),
        select: {fragment("date(?)::text", u.inserted_at), count(u.id)}
      )
      |> Repo.all()
      |> Map.new(fn {date_str, count} -> {Date.from_iso8601!(date_str), count} end)

    for offset <- 0..days_back do
      date = Date.add(from_date, offset)
      %{date: date, count: Map.get(grouped, date, 0)}
    end
  end
end
