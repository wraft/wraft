defmodule WraftDoc.Admin.AuditLogs.Diff do
  @moduledoc """
  Flattens an `ex_audit` patch term into a list of human-readable rows
  for the audit log detail view.

  A patch is the recursive `ExAudit.Diff.changes/0` type — typically a
  map of `{field, change}` pairs for `:created` / `:updated` / `:deleted`
  actions on Ecto schemas. Each row produced here has:

      %{path: "field.subfield", old: term | nil, new: term | nil, kind: :added | :removed | :changed}

  The `path` uses dotted-key notation and `[index]` for list positions
  so a reader can navigate nested changes without seeing the raw
  Erlang term structure.
  """

  @type row :: %{
          path: String.t(),
          old: term() | nil,
          new: term() | nil,
          kind: :added | :removed | :changed
        }

  @doc """
  Flattens a patch into a sorted list of diff rows. Stable sort by
  `path` so the rendered output is deterministic.
  """
  @spec flatten(term()) :: [row()]
  def flatten(patch) do
    patch
    |> walk("")
    |> Enum.sort_by(& &1.path)
  end

  # ----- recursive walker ---------------------------------------------------

  defp walk(:not_changed, _path), do: []

  defp walk({:primitive_change, a, b}, path), do: [row(path_or_root(path), a, b, :changed)]

  defp walk(%{} = changes, path) when not is_struct(changes) do
    Enum.flat_map(changes, fn {key, change} -> walk_field(path, key, change) end)
  end

  defp walk(changes, path) when is_list(changes) do
    Enum.flat_map(changes, &walk_list_change(path, &1))
  end

  # Anything else (shouldn't happen for a well-formed patch) — render
  # opaquely so we don't crash the detail view.
  defp walk(other, path), do: [row(path_or_root(path), nil, other, :changed)]

  defp walk_field(path, key, {:added, value}),
    do: [row(join(path, key), nil, value, :added)]

  defp walk_field(path, key, {:removed, value}),
    do: [row(join(path, key), value, nil, :removed)]

  defp walk_field(path, key, {:changed, change}),
    do: walk(change, join(path, key))

  defp walk_field(path, key, {:primitive_change, a, b}),
    do: [row(join(path, key), a, b, :changed)]

  defp walk_field(_path, _key, :not_changed), do: []

  defp walk_list_change(path, {:added_to_list, i, value}),
    do: [row("#{path_or_root(path)}[#{i}]", nil, value, :added)]

  defp walk_list_change(path, {:removed_from_list, i, value}),
    do: [row("#{path_or_root(path)}[#{i}]", value, nil, :removed)]

  defp walk_list_change(path, {:changed_in_list, i, change}),
    do: walk(change, "#{path_or_root(path)}[#{i}]")

  defp join("", key), do: to_string(key)
  defp join(path, key), do: "#{path}.#{key}"

  defp path_or_root(""), do: "(value)"
  defp path_or_root(path), do: path

  defp row(path, old, new, kind), do: %{path: path, old: old, new: new, kind: kind}

  @doc """
  Renders a value for display in the diff view. Strings are returned
  as-is (truncated if long); other terms go through `inspect/2`.
  """
  @spec format_value(term(), keyword()) :: String.t()
  def format_value(value, opts \\ [])
  def format_value(nil, _opts), do: "—"
  def format_value(value, opts) when is_binary(value), do: truncate(value, opts[:limit] || 200)
  def format_value(value, _opts) when is_atom(value), do: inspect(value)
  def format_value(value, _opts) when is_number(value), do: to_string(value)
  def format_value(value, _opts) when is_boolean(value), do: to_string(value)

  def format_value(%DateTime{} = dt, _opts),
    do: Calendar.strftime(dt, "%Y-%m-%d %H:%M:%S UTC")

  def format_value(%NaiveDateTime{} = dt, _opts),
    do: Calendar.strftime(dt, "%Y-%m-%d %H:%M:%S")

  def format_value(%Date{} = d, _opts), do: Date.to_iso8601(d)
  def format_value(value, opts), do: truncate(inspect(value, pretty: true), opts[:limit] || 200)

  defp truncate(string, max) when byte_size(string) <= max, do: string
  defp truncate(string, max), do: binary_part(string, 0, max) <> "…"
end
