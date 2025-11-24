defmodule WraftDoc.TokenEngine.Handlers.SmartTable do
  @moduledoc """
  Handler for Smart Table tokens.
  """

  @behaviour WraftDoc.TokenEngine.TokenHandler

  @impl true
  def validate(params), do: {:ok, params}

  @impl true
  def resolve(_token, _context),
    do: {:ok, %{rows: [["Header 1", "Header 2"], ["Row 1 Col 1", "Row 1 Col 2"]]}}

  @impl true
  def render(data, :markdown, _options) do
    rows = data.rows

    table_str =
      Enum.map_join(rows, "\n", fn row ->
        "| " <> Enum.join(row, " | ") <> " |"
      end)

    {:ok, "\n" <> table_str <> "\n"}
  end

  @impl true
  def render(data, :prosemirror, _options) do
    # Simple ProseMirror table generation
    rows = data.rows

    header_row = Enum.at(rows, 0)
    body_rows = Enum.drop(rows, 1)

    table_node = %{
      "type" => "table",
      "content" =>
        [
          # Simplified for brevity - normally would construct full table structure
          %{
            "type" => "tableRow",
            "content" =>
              Enum.map(header_row, fn cell ->
                %{
                  "type" => "tableHeader",
                  "content" => [
                    %{"type" => "paragraph", "content" => [%{"type" => "text", "text" => cell}]}
                  ]
                }
              end)
          }
        ] ++
          Enum.map(body_rows, fn row ->
            %{
              "type" => "tableRow",
              "content" =>
                Enum.map(row, fn cell ->
                  %{
                    "type" => "tableCell",
                    "content" => [
                      %{"type" => "paragraph", "content" => [%{"type" => "text", "text" => cell}]}
                    ]
                  }
                end)
            }
          end)
    }

    {:ok, table_node}
  end

  @impl true
  def render(_data, _format, _options), do: {:error, :unsupported_format}
end
