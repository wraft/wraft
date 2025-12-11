defmodule WraftDocWeb.Schemas.BlockTemplate do
  @moduledoc """
  Schema for BlockTemplate request and response
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

  defmodule BlockTemplateRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "BlockTemplate Request",
      description: "Create block_template request.",
      type: :object,
      properties: %{
        title: %Schema{type: :string, description: "The Title of the Block Template"},
        body: %Schema{type: :string, description: "The Body of the block template"},
        serialized: %Schema{type: :string, description: "The serialized of the block template"}
      },
      required: [:title, :body, :serialized],
      example: %{
        title: "a sample title",
        body: "a sample body",
        serialized: "a sample serialized"
      }
    })
  end

  defmodule BlockTemplate do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "BlockTemplate",
      description: "A BlockTemplate",
      type: :object,
      properties: %{
        title: %Schema{type: :string, description: "The Title of the block template"},
        body: %Schema{type: :string, description: "The Body of the block template"},
        serialized: %Schema{type: :string, description: "The serialized of the block template"},
        inserted_at: %Schema{
          type: :string,
          description: "When was the block_template inserted",
          format: "ISO-8601"
        },
        updated_at: %Schema{
          type: :string,
          description: "When was the block_template last updated",
          format: "ISO-8601"
        }
      },
      required: [:title, :body, :serialized],
      example: %{
        title: "a sample title",
        body: "a sample body",
        serialized: "a sample serialized",
        updated_at: "2020-01-21T14:00:00Z",
        inserted_at: "2020-02-21T14:00:00Z"
      }
    })
  end

  defmodule BlockTemplates do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "BlockTemplate list",
      type: :array,
      items: BlockTemplate
    })
  end

  defmodule BlockTemplateIndex do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "BlockTemplate Index",
      type: :object,
      properties: %{
        block_templates: BlockTemplates,
        page_number: %Schema{type: :integer, description: "Page number"},
        total_pages: %Schema{type: :integer, description: "Total number of pages"},
        total_entries: %Schema{type: :integer, description: "Total number of contents"}
      },
      example: %{
        block_templates: [
          %{
            title: "a sample title",
            body: "a sample body",
            serialized: "a sample serialized"
          },
          %{
            title: "a sample title",
            body: "a sample body",
            serialized: "a sample serialized"
          }
        ],
        page_number: 1,
        total_pages: 2,
        total_entries: 15
      }
    })
  end
end
