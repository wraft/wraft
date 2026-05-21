defmodule WraftDoc.Admin.PipelineMetrics do
  @moduledoc """
  Queries that power the admin Pipeline Metrics page at
  `/admin/pipeline-metrics`.

  Aggregates the `trigger_history` table — one row per pipeline run — into
  the same shape as `WraftDoc.Admin.BuildMetrics`: counts, error rate,
  duration percentiles, time-series throughput, and a paginated activity
  table.

  Status comes from `trigger_history.state`, a 1–6 integer mapped by
  `WraftDoc.Pipelines.TriggerHistories.TriggerHistory.states/0`:

      1 enqued · 2 executing · 3 pending
      4 partially_completed · 5 success · 6 failed

  For metrics we treat 5 as "success", 4 and 6 as "failed", and 1–3 as
  in-flight (not counted toward error rate). The `duration` column is
  already milliseconds.
  """
  import Ecto.Query

  alias WraftDoc.Admin.MetricRange
  alias WraftDoc.Enterprise.Organisation
  alias WraftDoc.Pipelines.Pipeline
  alias WraftDoc.Pipelines.TriggerHistories.TriggerHistory
  alias WraftDoc.Repo

  @default_page_size 25

  @success_state 5
  @failed_states [4, 6]
  @in_flight_states [1, 2, 3]

  @type list_opts :: [
          page: pos_integer(),
          page_size: pos_integer(),
          range: MetricRange.t(),
          status: String.t() | nil,
          organisation_id: Ecto.UUID.t() | nil
        ]

  # ---------------------------------------------------------------------------
  # Summary stats
  # ---------------------------------------------------------------------------

  @doc """
  Total / success / failed / in-flight counts, error rate, and avg + p95
  duration (ms) over the window. One SQL roundtrip.

  Runs without a `start_time` (still enqueued) contribute to `total` and
  `in_flight` but are excluded from duration aggregates.
  """
  @spec summary(MetricRange.t(), keyword()) :: %{
          total: non_neg_integer(),
          success: non_neg_integer(),
          failed: non_neg_integer(),
          in_flight: non_neg_integer(),
          error_rate: float() | nil,
          avg_ms: integer() | nil,
          p95_ms: integer() | nil
        }
  def summary(range, opts \\ []) do
    success = @success_state
    failed = @failed_states
    in_flight = @in_flight_states

    row =
      range
      |> base_query(opts)
      |> select([t], %{
        total: count(t.id),
        success: filter(count(t.id), t.state == ^success),
        failed: filter(count(t.id), t.state in ^failed),
        in_flight: filter(count(t.id), t.state in ^in_flight),
        avg_ms: avg(t.duration),
        p95_ms: fragment("percentile_cont(0.95) WITHIN GROUP (ORDER BY ?)", t.duration)
      })
      |> Repo.one()

    finished = row.success + row.failed

    error_rate =
      if finished > 0 do
        Float.round(row.failed / finished * 100, 1)
      end

    %{
      total: row.total,
      success: row.success,
      failed: row.failed,
      in_flight: row.in_flight,
      error_rate: error_rate,
      avg_ms: to_int(row.avg_ms),
      p95_ms: to_int(row.p95_ms)
    }
  end

  # ---------------------------------------------------------------------------
  # Time series
  # ---------------------------------------------------------------------------

  @doc """
  Bucketed run counts for the area chart. Same shape and zero-fill rules
  as `WraftDoc.Admin.BuildMetrics.time_series/2`. Buckets on
  `inserted_at` rather than `start_time` so still-enqueued runs are
  visible.
  """
  @spec time_series(MetricRange.t(), keyword()) :: [
          %{
            date: Date.t(),
            count: non_neg_integer(),
            success: non_neg_integer(),
            failed: non_neg_integer()
          }
        ]
  def time_series(%MetricRange{bucket: :hour} = range, opts) do
    success = @success_state
    failed = @failed_states

    grouped =
      range
      |> base_query(opts)
      |> group_by([t], fragment("date_trunc('hour', ?)", t.inserted_at))
      |> select([t], {
        fragment("date_trunc('hour', ?)", t.inserted_at),
        count(t.id),
        filter(count(t.id), t.state == ^success),
        filter(count(t.id), t.state in ^failed)
      })
      |> Repo.all()
      |> Map.new(fn {bucket, total, ok, fail} ->
        {NaiveDateTime.truncate(bucket, :second), {total, ok, fail}}
      end)

    base_hour = MetricRange.from_naive(range) |> NaiveDateTime.truncate(:second) |> floor_hour()

    for offset <- 0..23 do
      ts = NaiveDateTime.add(base_hour, offset * 3600, :second)
      {total, ok, fail} = Map.get(grouped, ts, {0, 0, 0})

      %{
        date: NaiveDateTime.to_date(ts),
        bucket_at: ts,
        count: total,
        success: ok,
        failed: fail
      }
    end
  end

  def time_series(%MetricRange{} = range, opts) do
    success = @success_state
    failed = @failed_states

    grouped =
      range
      |> base_query(opts)
      |> group_by([t], fragment("date(?)", t.inserted_at))
      |> select([t], {
        fragment("date(?)::text", t.inserted_at),
        count(t.id),
        filter(count(t.id), t.state == ^success),
        filter(count(t.id), t.state in ^failed)
      })
      |> Repo.all()
      |> Map.new(fn {date_str, total, ok, fail} ->
        {Date.from_iso8601!(date_str), {total, ok, fail}}
      end)

    from_date = DateTime.to_date(range.from)
    to_date = DateTime.to_date(range.to)

    for offset <- 0..Date.diff(to_date, from_date) do
      date = Date.add(from_date, offset)
      {total, ok, fail} = Map.get(grouped, date, {0, 0, 0})
      %{date: date, count: total, success: ok, failed: fail}
    end
  end

  # ---------------------------------------------------------------------------
  # Slowest / failed lists
  # ---------------------------------------------------------------------------

  @doc """
  Top `limit` triggers in the window by `duration` desc. Preloads
  pipeline (with organisation) and creator.
  """
  @spec slowest(MetricRange.t(), keyword(), pos_integer()) :: [TriggerHistory.t()]
  def slowest(range, opts \\ [], limit \\ 5) do
    range
    |> base_query(opts)
    |> where([t], not is_nil(t.duration))
    |> order_by([t], desc: t.duration)
    |> limit(^limit)
    |> preload(pipeline: [:organisation], creator: [])
    |> Repo.all()
  end

  @doc """
  Most-recent failed (or partially completed) triggers in the window.
  """
  @spec recent_failures(MetricRange.t(), keyword(), pos_integer()) :: [TriggerHistory.t()]
  def recent_failures(range, opts \\ [], limit \\ 5) do
    failed = @failed_states

    range
    |> base_query(opts)
    |> where([t], t.state in ^failed)
    |> order_by([t], desc: t.inserted_at, desc: t.id)
    |> limit(^limit)
    |> preload(pipeline: [:organisation], creator: [])
    |> Repo.all()
  end

  # ---------------------------------------------------------------------------
  # Paginated activity table
  # ---------------------------------------------------------------------------

  @spec list(list_opts()) :: %{
          entries: [TriggerHistory.t()],
          total: non_neg_integer(),
          page: pos_integer(),
          page_size: pos_integer(),
          page_count: non_neg_integer()
        }
  def list(opts \\ []) do
    page = max(opts[:page] || 1, 1)
    page_size = opts[:page_size] || @default_page_size
    offset = (page - 1) * page_size
    range = opts[:range] || MetricRange.default()

    query =
      range
      |> base_query(opts)
      |> apply_status(opts[:status])

    total = Repo.aggregate(query, :count, :id)

    entries =
      query
      |> order_by([t], desc: t.inserted_at, desc: t.id)
      |> preload(pipeline: [:organisation], creator: [])
      |> limit(^page_size)
      |> offset(^offset)
      |> Repo.all()

    %{
      entries: entries,
      total: total,
      page: page,
      page_size: page_size,
      page_count: ceil_div(total, page_size)
    }
  end

  @doc """
  Loads a trigger history row with pipeline + organisation + creator
  preloaded.
  """
  @spec get(any()) :: TriggerHistory.t() | nil
  def get(nil), do: nil
  def get(""), do: nil

  def get(id) when is_binary(id) do
    case Ecto.UUID.cast(id) do
      {:ok, uuid} ->
        TriggerHistory
        |> Repo.get(uuid)
        |> Repo.preload(pipeline: [:organisation], creator: [])

      :error ->
        nil
    end
  end

  # ---------------------------------------------------------------------------
  # Filter option helpers
  # ---------------------------------------------------------------------------

  @doc "Organisations with at least one trigger, alphabetised. Capped at 200."
  @spec organisation_options() :: [%{id: Ecto.UUID.t(), name: String.t()}]
  def organisation_options do
    Repo.all(
      from(t in TriggerHistory,
        join: p in Pipeline,
        on: p.id == t.pipeline_id,
        join: o in Organisation,
        on: o.id == p.organisation_id,
        distinct: o.id,
        order_by: [asc: o.name],
        select: %{id: o.id, name: o.name},
        limit: 200
      )
    )
  end

  @doc "Status filter values: 'success', 'failed', 'in_flight'."
  @spec statuses() :: [String.t()]
  def statuses, do: ["success", "failed", "in_flight"]

  @doc """
  Human label for the integer `state` enum — matches the atom names in
  `TriggerHistory.states/0`.
  """
  @spec state_label(integer() | nil) :: String.t()
  def state_label(1), do: "Enqueued"
  def state_label(2), do: "Executing"
  def state_label(3), do: "Pending"
  def state_label(4), do: "Partially completed"
  def state_label(5), do: "Success"
  def state_label(6), do: "Failed"
  def state_label(_), do: "Unknown"

  @doc "UI variant for the state badge."
  @spec state_variant(integer() | nil) :: String.t()
  def state_variant(5), do: "success"
  def state_variant(4), do: "warning"
  def state_variant(6), do: "error"
  def state_variant(s) when s in [1, 2, 3], do: "neutral"
  def state_variant(_), do: "ghost"

  # ---------------------------------------------------------------------------
  # Internals
  # ---------------------------------------------------------------------------

  defp base_query(range, opts) do
    from_naive = MetricRange.from_naive(range)
    to_naive = MetricRange.to_naive(range)

    TriggerHistory
    |> from()
    |> where([t], t.inserted_at >= ^from_naive and t.inserted_at <= ^to_naive)
    |> apply_organisation(opts[:organisation_id])
  end

  defp apply_organisation(query, id) when id in [nil, ""], do: query

  defp apply_organisation(query, id) when is_binary(id) do
    case Ecto.UUID.cast(id) do
      {:ok, uuid} ->
        from(t in query,
          join: p in Pipeline,
          on: p.id == t.pipeline_id and p.organisation_id == ^uuid
        )

      :error ->
        query
    end
  end

  defp apply_status(query, status) when status in [nil, ""], do: query

  defp apply_status(query, "success") do
    s = @success_state
    from(t in query, where: t.state == ^s)
  end

  defp apply_status(query, "failed") do
    states = @failed_states
    from(t in query, where: t.state in ^states)
  end

  defp apply_status(query, "in_flight") do
    states = @in_flight_states
    from(t in query, where: t.state in ^states)
  end

  defp apply_status(query, _), do: query

  defp to_int(nil), do: nil
  defp to_int(%Decimal{} = d), do: d |> Decimal.round() |> Decimal.to_integer()
  defp to_int(n) when is_float(n), do: round(n)
  defp to_int(n) when is_integer(n), do: n

  defp floor_hour(%NaiveDateTime{} = ndt) do
    %{ndt | minute: 0, second: 0, microsecond: {0, 0}}
  end

  defp ceil_div(_total, 0), do: 0
  defp ceil_div(total, _page_size) when total <= 0, do: 0
  defp ceil_div(total, page_size), do: div(total - 1, page_size) + 1
end
