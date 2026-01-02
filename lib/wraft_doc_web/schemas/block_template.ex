defmodule WraftDocWeb.Schemas.BlockTemplate do
  @moduledoc """
  Schema for BlockTemplate request and response
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema
  alias WraftDocWeb.Schemas.User

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
        id: %Schema{type: :string, description: "The ID of the block template"},
        title: %Schema{type: :string, description: "The Title of the block template"},
        body: %Schema{type: :string, description: "The Body of the block template"},
        serialized: %Schema{type: :string, description: "The serialized of the block template"},
        creator: User.UserIdAndName,
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
      required: [:id, :title, :body, :serialized],
      example: %{
        id: "123456789",
        title: "a sample title",
        body: "a sample body",
        serialized: "a sample serialized",
        creator: %{
          id: "123",
          name: "John Doe"
        },
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
      items: BlockTemplate,
      example: [
        %{
          id: "123456789",
          title: "a sample title",
          body: "a sample body",
          serialized: "a sample serialized",
          creator: %{
            id: "123",
            name: "John Doe"
          },
          updated_at: "2020-01-21T14:00:00Z",
          inserted_at: "2020-02-21T14:00:00Z"
        }
      ]
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
            id: "123456789",
            title: "a sample title",
            body: "a sample body",
            serialized: "a sample serialized",
            creator: %{
              id: "123",
              name: "John Doe"
            },
            updated_at: "2020-01-21T14:00:00Z",
            inserted_at: "2020-02-21T14:00:00Z"
          }
        ],
        page_number: 1,
        total_pages: 2,
        total_entries: 15
      }
    })
  end

  defmodule BulkImportResponse do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Bulk Import Response",
      type: :object,
      properties: %{
        info: %Schema{type: :string, description: "Info message"}
      },
      example: %{
        info: "Block Template will be created soon"
      }
    })
  end
end
