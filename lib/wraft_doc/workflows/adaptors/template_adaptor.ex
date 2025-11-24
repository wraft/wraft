defmodule WraftDoc.Workflows.Adaptors.TemplateAdaptor do
  @moduledoc """
  Template adaptor for WraftDoc workflows.
  """

  @behaviour WraftDoc.Workflows.Adaptors.Adaptor

  alias WraftDoc.Documents
  require Logger

  @impl true
  def execute(config, input_data, _credentials) do
    template_id = config["template_id"]
    template = WraftDoc.DataTemplates.get_data_template(template_id)

    input_tables = get_in(input_data, ["data", "tables"]) || %{}

    merged_serialized =
      inject_smart_tables(template.serialized, input_tables)

    params =
      %{}
      |> Documents.do_create_instance_params(%{template | serialized: merged_serialized})
      |> Map.merge(%{"type" => 3, "doc_settings" => %{}})

    current_user =
      input_data["user_id"]
      |> WraftDoc.Account.get_user_by_uuid()
      |> Map.put(:current_org_id, input_data["org_id"])

    Documents.create_instance(
      current_user,
      template.content_type,
      params
    )

    {:ok, %{generated_at: DateTime.utc_now(), metadata: %{}}}
  end

  # TODO: Move into token replacement engine
  # ————————————————————————————————————————————————————————————
  # SMART TABLE PROCESSING
  # ————————————————————————————————————————————————————————————
  def inject_smart_tables(serialized_map, smart_tables) do
    doc = Jason.decode!(serialized_map["data"])

    new_content =
      Enum.map(doc["content"], fn
        %{
          "type" => "smartTableWrapper",
          "attrs" => %{"tableName" => table_name},
          "content" => content
        } = node ->
          incoming = smart_tables[table_name]

          cond do
            incoming == nil ->
              node

            is_map(incoming) and incoming["add_to_existing"] == true and is_list(content) and
                content != [] ->
              updated_node = append_rows_to_existing(node, incoming)
              updated_node

            is_list(content) and content != [] ->
              node

            true ->
              table_node = build_prosemirror_table(incoming)
              Map.put(node, "content", [table_node])
          end

        other ->
          other
      end)

    %{serialized_map | "data" => Jason.encode!(%{doc | "content" => new_content})}
  end

  def build_prosemirror_table(
        %{
          "headers" => headers,
          "rows" => rows
        } = data
      ) do
    footer = Map.get(data, "footer", nil)

    header_row =
      %{
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

  defp append_rows_to_existing(
         %{
           "content" => [table_node]
         } = wrapper_node,
         %{"rows" => new_rows} = _incoming
       ) do
    table_content = get_in(table_node, ["content"]) || []
    new_rows_pm = Enum.map(new_rows, &pm_row/1)

    updated_table_node = put_in(table_node, ["content"], table_content ++ new_rows_pm)
    put_in(wrapper_node, ["content"], [updated_table_node])
  end
end
