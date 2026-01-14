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

    Now also checks for machineName first, then falls back to tableName for lookup.
  """
  def resolve(token, context) do
    machine_name = token.params["machineName"] || token.params["machine_name"]
    table_name = token.params["tableName"]

    data =
      cond do
        machine_name && Map.has_key?(context, machine_name) ->
          Map.get(context, machine_name)

        table_name && Map.has_key?(context, table_name) ->
          Map.get(context, table_name)

        true ->
          nil
      end

    data = validate_table_map(data)

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

  def render(%{data: "", original_node: node}, :prosemirror, _options), do: {:ok, node}

  def render(%{data: nil, original_node: node}, :prosemirror, _options), do: {:ok, node}

  def render(%{data: data, original_node: node}, :prosemirror, _options) when is_map(data) do
    colwidths = extract_colwidths(node)
    table_node = build_prosemirror_table(data, colwidths)

    {:ok, Map.put(node, "content", [table_node])}
  end

  @impl true
  def render(_data, _format, _options), do: {:error, :unsupported_format}

  defp build_prosemirror_table(%{"headers" => headers, "rows" => rows} = data, colwidths) do
    footer = Map.get(data, "footer", nil)

    header_row = [
      %{
        "type" => "tableRow",
        "content" =>
          headers
          |> Enum.with_index()
          |> Enum.map(fn {text, idx} -> pm_smart_header_cell(text, Enum.at(colwidths, idx)) end)
      }
    ]

    rows_pm = Enum.map(rows, fn row -> pm_smart_row(row, colwidths) end)

    footer_pm =
      case footer do
        nil -> []
        [] -> []
        values -> [pm_smart_row(values, colwidths)]
      end

    %{
      "type" => "table",
      "content" => header_row ++ rows_pm ++ footer_pm
    }
  end

  defp pm_smart_header_cell(text, colwidth) do
    %{
      "type" => "tableCell",
      "attrs" => %{"alignment" => nil, "colspan" => 1, "colwidth" => colwidth, "rowspan" => 1},
      "content" => [
        %{
          "type" => "paragraph",
          "content" => [
            %{
              "type" => "text",
              "marks" => [%{"type" => "bold"}],
              "text" => text
            }
          ]
        }
      ]
    }
  end

  defp pm_smart_row(cells, colwidths) do
    %{
      "type" => "tableRow",
      "content" =>
        cells
        |> Enum.with_index()
        |> Enum.map(fn {cell_text, idx} ->
          %{
            "type" => "tableCell",
            "attrs" => %{
              "alignment" => nil,
              "colspan" => 1,
              "colwidth" => Enum.at(colwidths, idx),
              "rowspan" => 1
            },
            "content" => [
              %{
                "type" => "paragraph",
                "content" => [%{"type" => "text", "text" => to_string(cell_text)}]
              }
            ]
          }
        end)
    }
  end

  defp extract_colwidths(%{"content" => content}) when is_list(content) do
    with %{"content" => rows} when is_list(rows) <-
           Enum.find(content, fn node -> node["type"] == "table" end),
         %{"content" => cells} when is_list(cells) <-
           Enum.find(rows, fn node -> node["type"] == "tableRow" end) do
      Enum.map(cells, fn cell ->
        get_in(cell, ["attrs", "colwidth"])
      end)
    else
      _ -> []
    end
  end

  defp extract_colwidths(_), do: []

  defp validate_table_map(%{"type" => "table", "rows" => _rows} = data)
       when is_map(data), do: data

  defp validate_table_map(_), do: nil
end
