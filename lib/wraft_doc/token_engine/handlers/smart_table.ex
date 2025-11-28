defmodule WraftDoc.TokenEngine.Handlers.SmartTable do
  @moduledoc """
  Handler for Smart Table tokens.
  """

  @behaviour WraftDoc.TokenEngine.TokenHandler

  @impl true
  def validate(params), do: {:ok, params}

  @impl true
  @doc """
    Context is expected to be the map of smart_tables, or a map containing "smart_tables" key
    Based on template_adaptor.ex: incoming = smart_tables[table_name]

    We'll assume context IS the smart_tables map for simplicity, or we check for a key.
    Let's support both for flexibility.
  """
  def resolve(token, context) do
    table_name = token.params["tableName"]
    data = Map.get(context, table_name)

    {:ok, %{data: data, original_node: token.original_node}}
  end

  @impl true
  def render(%{data: nil}, :markdown, _options) do
    {:ok, ""}
  end

  def render(%{data: data}, :markdown, _options) do
    rows = data["rows"] || []
    headers = data["headers"] || []

    all_rows = [headers | rows]

    table_str =
      Enum.map_join(all_rows, "\n", fn row ->
        "| " <> Enum.join(row, " | ") <> " |"
      end)

    {:ok, "\n" <> table_str <> "\n"}
  end

  @impl true
  def render(%{data: nil, original_node: node}, :prosemirror, _options) do
    {:ok, node}
  end

  def render(%{data: data, original_node: node}, :prosemirror, _options) do
    table_node = build_prosemirror_table(data)

    {:ok, Map.put(node, "content", [table_node])}
  end

  @impl true
  def render(_data, _format, _options), do: {:error, :unsupported_format}

  defp build_prosemirror_table(%{"headers" => headers, "rows" => rows} = data) do
    footer = Map.get(data, "footer", nil)

    header_row = %{
      "type" => "tableRow",
      "content" =>
        Enum.map(headers, fn text ->
          %{
            "type" => "tableHeaderCell",
            "attrs" => %{"colspan" => 1, "rowspan" => 1, "colwidth" => nil},
            "content" => [
              %{
                "type" => "paragraph",
                "content" => [%{"type" => "text", "text" => text}]
              }
            ]
          }
        end)
    }

    rows_pm = Enum.map(rows, &pm_row/1)

    footer_pm =
      case footer do
        nil -> []
        [] -> []
        footer_values -> [pm_row(footer_values)]
      end

    %{
      "type" => "table",
      "content" => [header_row] ++ rows_pm ++ footer_pm
    }
  end

  defp pm_cell(text) do
    %{
      "type" => "tableCell",
      "attrs" => %{"colspan" => 1, "rowspan" => 1, "colwidth" => nil},
      "content" => [
        %{
          "type" => "paragraph",
          "content" => [%{"type" => "text", "text" => text}]
        }
      ]
    }
  end

  defp pm_row(cells) do
    %{
      "type" => "tableRow",
      "content" => Enum.map(cells, &pm_cell/1)
    }
  end
end
