defmodule WraftDoc.Admin.QueueMonitoring do
  @moduledoc """
  Queries that power the admin Queue Monitoring page at `/admin/queue-monitoring`.

  Reads directly from the `oban_jobs` table (via `Oban.Job`) for state and
  per-queue breakdowns, and from `Oban.check_all_queues/0` to surface the
  live producer state (currently-running, paused, etc.) of each queue
  configured under `config :wraft_doc, Oban`.

  Strictly read-only — administrative actions on jobs (cancel/retry/delete)
  are intentionally out of scope here. Operators who need that should use
  the Oban Web dashboard mounted at `/oban`.
  """
  import Ecto.Query

  alias Oban.Job
  alias WraftDoc.Repo

  @default_page_size 25
  @states ~w(available scheduled executing retryable completed discarded cancelled)
  @failure_states ~w(discarded cancelled retryable)

  @type list_opts :: [
          page: pos_integer(),
          page_size: pos_integer(),
          state: String.t() | nil,
          queue: String.t() | nil,
          worker: String.t() | nil
        ]

  # ---------------------------------------------------------------------------
  # Summary counts (state x time)
  # ---------------------------------------------------------------------------

  @doc """
  Returns the count of jobs in each Oban state across the whole `oban_jobs`
  table. `:completed` reflects only the retention window kept by
  `Oban.Plugins.Pruner` (60 s by default in this project), so it will read
  low in steady state — that's expected.
  """
  @spec state_counts() :: %{required(String.t()) => non_neg_integer(), total: non_neg_integer()}
  def state_counts do
    rows =
      Job
      |> group_by([j], j.state)
      |> select([j], {j.state, count(j.id)})
      |> Repo.all()
      |> Map.new()

    base = Map.new(@states, &{&1, Map.get(rows, &1, 0)})
    Map.put(base, :total, Enum.sum(Map.values(base)))
  end

  @doc """
  Counts of jobs inserted in the last `hours_back` hours. Useful as a
  throughput proxy on the dashboard. Includes jobs in any state (so it
  still works even after the Pruner has reaped completions).
  """
  @spec throughput(non_neg_integer()) :: %{inserted: non_neg_integer(), failed: non_neg_integer()}
  def throughput(hours_back \\ 24) do
    since = DateTime.add(DateTime.utc_now(), -hours_back * 3600, :second)

    inserted =
      Repo.aggregate(from(j in Job, where: j.inserted_at >= ^since), :count, :id)

    failed =
      Repo.aggregate(
        from(j in Job,
          where: j.inserted_at >= ^since and j.state in ^@failure_states
        ),
        :count,
        :id
      )

    %{inserted: inserted, failed: failed}
  end

  # ---------------------------------------------------------------------------
  # Per-queue breakdown
  # ---------------------------------------------------------------------------

  @doc """
  Per-queue rollup combining:

  - the queues declared in `config :wraft_doc, Oban, queues: …` (with their
    configured concurrency limit),
  - the per-state counts of jobs currently sitting in that queue, and
  - the live producer state (`paused?`, `running_count`) reported by
    `Oban.check_all_queues/0` when Oban is running.

  Queues that exist in config but have no jobs yet still appear in the
  list, so operators can confirm every queue is wired up.
  """
  @spec queue_breakdown() :: [
          %{
            queue: String.t(),
            limit: non_neg_integer() | nil,
            states: %{required(String.t()) => non_neg_integer()},
            total: non_neg_integer(),
            producer: map() | nil
          }
        ]
  def queue_breakdown do
    db_rows =
      Job
      |> group_by([j], [j.queue, j.state])
      |> select([j], {j.queue, j.state, count(j.id)})
      |> Repo.all()

    grouped =
      Enum.reduce(db_rows, %{}, fn {queue, state, count}, acc ->
        Map.update(acc, queue, %{state => count}, &Map.put(&1, state, count))
      end)

    producers = Map.new(live_producers(), fn p -> {to_string(p.queue), p} end)

    queue_names =
      MapSet.union(MapSet.new(Map.keys(grouped)), MapSet.new(Map.keys(configured_queues())))

    queue_names
    |> MapSet.to_list()
    |> Enum.sort()
    |> Enum.map(fn queue ->
      states = Map.get(grouped, queue, %{})
      filled = Map.new(@states, &{&1, Map.get(states, &1, 0)})

      %{
        queue: queue,
        limit: Map.get(configured_queues(), queue),
        states: filled,
        total: Enum.sum(Map.values(filled)),
        producer: Map.get(producers, queue)
      }
    end)
  end

  @doc """
  Returns `%{queue_name_string => limit}` from app config. The Oban config
  declares queues as a keyword list — we normalise to string keys to match
  the `oban_jobs.queue` column.
  """
  @spec configured_queues() :: %{String.t() => non_neg_integer()}
  def configured_queues do
    :wraft_doc
    |> Application.get_env(Oban, [])
    |> Keyword.get(:queues, [])
    |> Map.new(fn
      {name, limit} when is_integer(limit) -> {to_string(name), limit}
      {name, opts} when is_list(opts) -> {to_string(name), Keyword.get(opts, :limit)}
      {name, _other} -> {to_string(name), nil}
    end)
  end

  # `Oban.check_all_queues/0` raises if Oban is not started (e.g. some test
  # environments). Wrap to keep the page robust.
  defp live_producers do
    Oban.check_all_queues()
  rescue
    _ -> []
  catch
    :exit, _ -> []
  end

  # ---------------------------------------------------------------------------
  # Job listing (paginated, filtered)
  # ---------------------------------------------------------------------------

  @doc """
  Returns a page of `oban_jobs` rows along with pagination metadata. Unknown
  / blank filters are ignored. Ordered newest-first by id (which is monotonic
  for Oban) so callers see the most recent activity first.
  """
  @spec list(list_opts()) :: %{
          entries: [Job.t()],
          total: non_neg_integer(),
          page: pos_integer(),
          page_size: pos_integer(),
          page_count: non_neg_integer()
        }
  def list(opts \\ []) do
    page = max(opts[:page] || 1, 1)
    page_size = opts[:page_size] || @default_page_size
    offset = (page - 1) * page_size

    query = build_query(opts)
    total = Repo.aggregate(query, :count, :id)

    entries =
      query
      |> order_by([j], desc: j.id)
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
  Fetches a single job by its integer id. Returns `nil` if not found or the
  id can't be parsed.
  """
  @spec get(integer() | String.t() | nil) :: Job.t() | nil
  def get(nil), do: nil
  def get(""), do: nil

  def get(id) when is_binary(id) do
    case Integer.parse(id) do
      {int, ""} -> get(int)
      _ -> nil
    end
  end

  def get(id) when is_integer(id), do: Repo.get(Job, id)

  @doc """
  Recent failed jobs (state in #{inspect(@failure_states)}), newest first,
  with their last error preserved on the row. Used by the "Recent failures"
  card on the index page.
  """
  @spec recent_failures(non_neg_integer()) :: [Job.t()]
  def recent_failures(limit \\ 5) do
    Repo.all(
      from(j in Job,
        where: j.state in ^@failure_states,
        order_by: [desc: j.id],
        limit: ^limit
      )
    )
  end

  # ---------------------------------------------------------------------------
  # Filter option helpers
  # ---------------------------------------------------------------------------

  @doc "Allowed Oban states (as strings) for the state filter dropdown."
  @spec states() :: [String.t()]
  def states, do: @states

  @doc """
  Distinct worker names currently in the table, ordered alphabetically.
  Used to populate the worker filter dropdown. Caps at 200 to keep the
  dropdown manageable.
  """
  @spec workers() :: [String.t()]
  def workers do
    Repo.all(
      from(j in Job,
        distinct: true,
        select: j.worker,
        order_by: [asc: j.worker],
        limit: 200
      )
    )
  end

  @doc "Distinct queue names present in the table, ordered alphabetically."
  @spec queues() :: [String.t()]
  def queues do
    db =
      Repo.all(
        from(j in Job,
          distinct: true,
          select: j.queue,
          order_by: [asc: j.queue]
        )
      )

    (db ++ Map.keys(configured_queues()))
    |> Enum.uniq()
    |> Enum.sort()
  end

  # ---------------------------------------------------------------------------
  # Internals
  # ---------------------------------------------------------------------------

  defp build_query(opts) do
    Job
    |> from()
    |> apply_state(opts[:state])
    |> apply_queue(opts[:queue])
    |> apply_worker(opts[:worker])
  end

  defp apply_state(query, state) when state in [nil, ""], do: query

  defp apply_state(query, state) when is_binary(state) do
    if state in @states, do: from(j in query, where: j.state == ^state), else: query
  end

  defp apply_queue(query, queue) when queue in [nil, ""], do: query

  defp apply_queue(query, queue) when is_binary(queue),
    do: from(j in query, where: j.queue == ^queue)

  defp apply_worker(query, worker) when worker in [nil, ""], do: query

  defp apply_worker(query, worker) when is_binary(worker) do
    like = "%#{worker}%"
    from(j in query, where: ilike(j.worker, ^like))
  end

  defp ceil_div(_total, 0), do: 0
  defp ceil_div(total, _page_size) when total <= 0, do: 0
  defp ceil_div(total, page_size), do: div(total - 1, page_size) + 1
end
