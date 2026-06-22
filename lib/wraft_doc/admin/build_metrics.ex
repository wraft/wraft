defmodule WraftDoc.Admin.BuildMetrics do
  @moduledoc """
  Queries that power the admin Build Metrics page at `/admin/build-metrics`.

  Aggregates the `build_history` table — one row per document render
  attempt — into operational signals: success/failure counts, average and
  p95 duration, time-series throughput, and a paginated activity table.

  Organisation filtering joins through `build_history.content_id →
  content.organisation_id`. The `delay` column stores duration in
  milliseconds (see `WraftDoc.Documents.Instance.History`).

  Strictly read-only — there are no admin actions on individual build
  rows.
  """
  import Ecto.Query

  alias WraftDoc.Admin.MetricRange
  alias WraftDoc.Documents.Instance
  alias WraftDoc.Documents.Instance.History
  alias WraftDoc.Enterprise.Organisation
  alias WraftDoc.Repo

  @default_page_size 25

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
  Headline numbers for the stat-card row: total runs, success/failed
  counts, error rate, average and p95 duration (ms) over the window.

  All in a single SQL roundtrip — `percentile_cont(0.95) WITHIN GROUP`
  (a Postgres built-in) computes p95 without pulling the rows back into
  Elixir.
  """
  @spec summary(MetricRange.t(), keyword()) :: %{
          total: non_neg_integer(),
          success: non_neg_integer(),
          failed: non_neg_integer(),
          error_rate: float() | nil,
          avg_ms: integer() | nil,
          p95_ms: integer() | nil
        }
  def summary(range, opts \\ []) do
    row =
      range
      |> base_query(opts)
      |> select([h], %{
        total: count(h.id),
        success: filter(count(h.id), h.status == "success"),
        failed: filter(count(h.id), h.status != "success"),
        avg_ms: avg(h.delay),
        p95_ms: fragment("percentile_cont(0.95) WITHIN GROUP (ORDER BY ?)", h.delay)
      })
      |> Repo.one()

    total = row.total
    failed = row.failed

    error_rate =
      if total > 0 do
        Float.round(failed / total * 100, 1)
      end

    %{
      total: total,
      success: row.success,
      failed: failed,
      error_rate: error_rate,
      avg_ms: to_int(row.avg_ms),
      p95_ms: to_int(row.p95_ms)
    }
  end

  # ---------------------------------------------------------------------------
  # Time series
  # ---------------------------------------------------------------------------

  @doc """
  Bucketed run counts for the area chart — one entry per hour (24-hour
  window) or per day (everything else). Empty buckets are filled with
  zeros so the x-axis is continuous. Splits each bucket into `total`,
  `success`, and `failed` so the LiveView can pick what to render.

  The shape (`%{date: Date.t(), count: integer()}`) matches what
  `WraftDocWeb.AdminNext.UI.area_chart/1` expects — `count` carries the
  total; `success` / `failed` are available for richer renders later.
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
    grouped =
      range
      |> base_query(opts)
      |> group_by([h], fragment("date_trunc('hour', ?)", h.start_time))
      |> select([h], {
        fragment("date_trunc('hour', ?)", h.start_time),
        count(h.id),
        filter(count(h.id), h.status == "success"),
        filter(count(h.id), h.status != "success")
      })
      |> Repo.all()
      |> Map.new(fn {bucket, total, success, failed} ->
        {NaiveDateTime.truncate(bucket, :second), {total, success, failed}}
      end)

    from_naive = MetricRange.from_naive(range)
    base_hour = from_naive |> NaiveDateTime.truncate(:second) |> floor_hour()

    for offset <- 0..23 do
      ts = NaiveDateTime.add(base_hour, offset * 3600, :second)
      {total, success, failed} = Map.get(grouped, ts, {0, 0, 0})

      %{
        date: NaiveDateTime.to_date(ts),
        bucket_at: ts,
        count: total,
        success: success,
        failed: failed
      }
    end
  end

  def time_series(%MetricRange{} = range, opts) do
    grouped =
      range
      |> base_query(opts)
      |> group_by([h], fragment("date(?)", h.start_time))
      |> select([h], {
        fragment("date(?)::text", h.start_time),
        count(h.id),
        filter(count(h.id), h.status == "success"),
        filter(count(h.id), h.status != "success")
      })
      |> Repo.all()
      |> Map.new(fn {date_str, total, success, failed} ->
        {Date.from_iso8601!(date_str), {total, success, failed}}
      end)

    from_date = DateTime.to_date(range.from)
    to_date = DateTime.to_date(range.to)

    for offset <- 0..Date.diff(to_date, from_date) do
      date = Date.add(from_date, offset)
      {total, success, failed} = Map.get(grouped, date, {0, 0, 0})
      %{date: date, count: total, success: success, failed: failed}
    end
  end

  # ---------------------------------------------------------------------------
  # Slowest / failed lists
  # ---------------------------------------------------------------------------

  @doc """
  Top `limit` builds in the window by `delay` desc — surfaces outliers
  faster than scrolling the activity table. Preloads `content` and
  `creator` so the row can show what was built and by whom.
  """
  @spec slowest(MetricRange.t(), keyword(), pos_integer()) :: [History.t()]
  def slowest(range, opts \\ [], limit \\ 5) do
    range
    |> base_query(opts)
    |> where([h], not is_nil(h.delay))
    |> order_by([h], desc: h.delay)
    |> limit(^limit)
    |> preload([:content, :creator])
    |> Repo.all()
  end

  @doc """
  Most-recent non-success builds in the window. Empty list when the
  system is healthy.
  """
  @spec recent_failures(MetricRange.t(), keyword(), pos_integer()) :: [History.t()]
  def recent_failures(range, opts \\ [], limit \\ 5) do
    range
    |> base_query(opts)
    |> where([h], h.status != "success")
    |> order_by([h], desc: h.inserted_at, desc: h.id)
    |> limit(^limit)
    |> preload([:content, :creator])
    |> Repo.all()
  end

  # ---------------------------------------------------------------------------
  # Paginated activity table
  # ---------------------------------------------------------------------------

  @doc """
  Paginated list with the same filters as `summary/2` plus optional
  `status` ("success" | "failed"). Newest first. Shape mirrors
  `WraftDoc.Admin.QueueMonitoring.list/1` so the LiveView pagination
  helpers can be reused.
  """
  @spec list(list_opts()) :: %{
          entries: [History.t()],
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
      |> order_by([h], desc: h.inserted_at, desc: h.id)
      |> preload([:content, :creator])
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
  Loads a single build with `content`, `creator`, and the parent
  organisation preloaded. `nil` on bad input.
  """
  @spec get(any()) :: History.t() | nil
  def get(nil), do: nil
  def get(""), do: nil

  def get(id) when is_binary(id) do
    case Ecto.UUID.cast(id) do
      {:ok, uuid} ->
        History
        |> Repo.get(uuid)
        |> Repo.preload(content: [:organisation], creator: [])

      :error ->
        nil
    end
  end

  # ---------------------------------------------------------------------------
  # Filter option helpers
  # ---------------------------------------------------------------------------

  @doc """
  Organisations that have produced at least one build, alphabetised.
  Capped at 200 to keep the dropdown manageable.
  """
  @spec organisation_options() :: [%{id: Ecto.UUID.t(), name: String.t()}]
  def organisation_options do
    Repo.all(
      from(h in History,
        join: i in Instance,
        on: i.id == h.content_id,
        join: o in Organisation,
        on: o.id == i.organisation_id,
        distinct: o.id,
        order_by: [asc: o.name],
        select: %{id: o.id, name: o.name},
        limit: 200
      )
    )
  end

  @doc "Allowed status filters."
  @spec statuses() :: [String.t()]
  def statuses, do: ["success", "failed"]

  # ---------------------------------------------------------------------------
  # Internals
  # ---------------------------------------------------------------------------

  defp base_query(range, opts) do
    from_naive = MetricRange.from_naive(range)
    to_naive = MetricRange.to_naive(range)

    History
    |> from()
    |> where([h], h.start_time >= ^from_naive and h.start_time <= ^to_naive)
    |> apply_organisation(opts[:organisation_id])
  end

  defp apply_organisation(query, id) when id in [nil, ""], do: query

  defp apply_organisation(query, id) when is_binary(id) do
    case Ecto.UUID.cast(id) do
      {:ok, uuid} ->
        from(h in query,
          join: i in Instance,
          on: i.id == h.content_id and i.organisation_id == ^uuid
        )

      :error ->
        query
    end
  end

  defp apply_status(query, status) when status in [nil, ""], do: query

  defp apply_status(query, "success"),
    do: from(h in query, where: h.status == "success")

  defp apply_status(query, "failed"),
    do: from(h in query, where: h.status != "success")

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
