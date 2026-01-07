defmodule WraftDocWeb.Schemas.Document do
  @moduledoc """
  OpenAPI schemas for Document operations
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

  defmodule ImportDocxResponse do
    @moduledoc """
    Response schema for importing DOCX files
    """
    OpenApiSpex.schema(%{
      title: "Import Docx Response",
      description: "Response for importing docx file containing ProseMirror JSON",
      type: :object,
      properties: %{
        prosemirror: %Schema{
          type: :object,
          description: "ProseMirror JSON document structure",
          example: %{
            "type" => "doc",
            "content" => [
              %{
                "type" => "heading",
                "attrs" => %{"level" => 1},
                "content" => [%{"type" => "text", "text" => "Hello"}]
              },
              %{
                "type" => "paragraph",
                "content" => [%{"type" => "text", "text" => "World"}]
              }
            ]
          }
        }
      },
      required: [:prosemirror],
      example: %{
        prosemirror: %{
          "type" => "doc",
          "content" => [
            %{
              "type" => "heading",
              "attrs" => %{"level" => 1},
              "content" => [%{"type" => "text", "text" => "Hello"}]
            },
            %{
              "type" => "paragraph",
              "content" => [%{"type" => "text", "text" => "World"}]
            }
          ]
        }
      }
    })
  end
end
