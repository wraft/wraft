defmodule WraftDoc.Admin.AuditLogs do
  @moduledoc """
  Queries that power the admin Audit Logs page.

  Sources the `ex_audit_version` table (system-wide changes captured by the
  `ex_audit` library on every create/update/delete to a tracked schema).
  Tracked schemas are configured in `config/config.exs` under
  `:ex_audit, :tracked_schemas`.
  """
  import Ecto.Query

  alias WraftDoc.ExAudit.Version
  alias WraftDoc.Repo

  @default_page_size 25
  @actions ~w(created updated deleted)a

  @type list_opts :: [
          page: pos_integer(),
          page_size: pos_integer(),
          action: String.t() | nil,
          schema: String.t() | nil,
          search: String.t() | nil
        ]

  @doc """
  Returns a page of audit log rows along with pagination metadata. The
  caller passes the active filter values; unknown / blank filters are
  ignored.
  """
  @spec list(list_opts()) :: %{
          entries: [Version.t()],
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
      |> order_by([v], desc: v.recorded_at, desc: v.id)
      |> preload(:user)
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
  Fetches a single audit log entry by its integer id, with the actor
  user preloaded. Returns `nil` if not found or the id can't be parsed.
  """
  @spec get(integer() | String.t() | nil) :: Version.t() | nil
  def get(nil), do: nil
  def get(""), do: nil

  def get(id) when is_binary(id) do
    case Integer.parse(id) do
      {int, ""} -> get(int)
      _ -> nil
    end
  end

  def get(id) when is_integer(id) do
    Version
    |> Repo.get(id)
    |> Repo.preload(:user)
  end

  @doc """
  Counts of audit events grouped by action across the full table. Useful
  for surfacing summary stat cards above the table.
  """
  @spec counts() :: %{
          created: non_neg_integer(),
          updated: non_neg_integer(),
          deleted: non_neg_integer(),
          total: non_neg_integer()
        }
  def counts do
    query =
      from(v in Version,
        group_by: v.action,
        select: {v.action, count(v.id)}
      )

    rows = query |> Repo.all() |> Map.new()

    created = Map.get(rows, :created, 0)
    updated = Map.get(rows, :updated, 0)
    deleted = Map.get(rows, :deleted, 0)

    %{
      created: created,
      updated: updated,
      deleted: deleted,
      total: created + updated + deleted
    }
  end

  @doc """
  Daily count of audit events for the last `days_back` days (default 30),
  oldest day first, with empty days zero-filled so the chart's x-axis is
  continuous. Respects the same `:action`, `:schema`, and `:search` opts
  as `list/1`, so the chart and the table view stay in sync.
  """
  @spec daily_activity(non_neg_integer(), list_opts()) :: [%{date: Date.t(), count: integer()}]
  def daily_activity(days_back \\ 30, opts \\ []) do
    today = Date.utc_today()
    from_date = Date.add(today, -days_back)
    {:ok, from_naive} = NaiveDateTime.new(from_date, ~T[00:00:00])

    grouped =
      opts
      |> build_query()
      |> where([v], v.recorded_at >= ^from_naive)
      |> group_by([v], fragment("date(?)", v.recorded_at))
      |> select([v], {fragment("date(?)::text", v.recorded_at), count(v.id)})
      |> Repo.all()
      |> Map.new(fn {date_str, count} -> {Date.from_iso8601!(date_str), count} end)

    for offset <- 0..days_back do
      date = Date.add(from_date, offset)
      %{date: date, count: Map.get(grouped, date, 0)}
    end
  end

  @doc """
  Returns the list of tracked schema atoms in the order they are configured.
  Used to populate the entity-type filter dropdown.
  """
  @spec tracked_schemas() :: [module()]
  def tracked_schemas, do: Application.get_env(:ex_audit, :tracked_schemas, [])

  @doc """
  Humanised label for a tracked schema module — e.g.
  `WraftDoc.Documents.Instance` → "Documents · Instance".
  """
  @spec schema_label(module() | nil) :: String.t()
  def schema_label(nil), do: "—"

  def schema_label(module) when is_atom(module) do
    module
    |> Module.split()
    |> case do
      ["WraftDoc" | rest] -> rest
      other -> other
    end
    |> Enum.map_join(" · ", &humanize_segment/1)
  end

  @doc """
  Allowed actions for the action filter dropdown.
  """
  @spec actions() :: [atom()]
  def actions, do: @actions

  # ----- internals ----------------------------------------------------------

  defp build_query(opts) do
    Version
    |> from()
    |> apply_action(opts[:action])
    |> apply_schema(opts[:schema])
    |> apply_search(opts[:search])
  end

  defp apply_action(query, action) when action in [nil, ""], do: query

  defp apply_action(query, action) when is_binary(action) do
    case action_atom(action) do
      nil -> query
      atom -> from(v in query, where: v.action == ^atom)
    end
  end

  defp apply_schema(query, schema) when schema in [nil, ""], do: query

  defp apply_schema(query, schema) when is_binary(schema) do
    case schema_atom(schema) do
      nil -> query
      module -> from(v in query, where: v.entity_schema == ^module)
    end
  end

  defp apply_search(query, search) when search in [nil, ""], do: query

  defp apply_search(query, search) when is_binary(search) do
    like = "%#{search}%"

    from(v in query,
      left_join: u in assoc(v, :user),
      where: ilike(u.email, ^like) or ilike(u.name, ^like)
    )
  end

  defp action_atom("created"), do: :created
  defp action_atom("updated"), do: :updated
  defp action_atom("deleted"), do: :deleted
  defp action_atom(_), do: nil

  defp schema_atom(string) do
    Enum.find(tracked_schemas(), fn mod -> Atom.to_string(mod) == string end)
  end

  defp humanize_segment(segment) do
    segment
    |> String.replace(~r/([a-z\d])([A-Z])/, "\\1 \\2")
    |> String.replace("_", " ")
  end

  defp ceil_div(_total, 0), do: 0
  defp ceil_div(total, _page_size) when total <= 0, do: 0
  defp ceil_div(total, page_size), do: div(total - 1, page_size) + 1
end
