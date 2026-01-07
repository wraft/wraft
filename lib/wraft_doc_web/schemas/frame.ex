defmodule WraftDocWeb.Schemas.Frame do
  @moduledoc """
  Schema for Frame request and response
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema
  alias WraftDocWeb.Schemas.Asset

  defmodule Frame do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Frame",
      description: "A Frame resource",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "Unique identifier for the frame"},
        name: %Schema{type: :string, description: "Name of the frame"},
        type: %Schema{type: :string, description: "Type of the frame"},
        description: %Schema{type: :string, description: "Description of the frame"},
        thumbnail: %Schema{type: :string, description: "URL of the frame thumbnail"},
        asset: Asset.Asset,
        fields: %Schema{
          type: :array,
          description: "Fields in the frame",
          items: %Schema{type: :object}
        },
        meta: %Schema{type: :object, description: "Metadata (wraft_json)"},
        inserted_at: %Schema{
          type: :string,
          description: "Timestamp of frame creation",
          format: "ISO-8601"
        },
        updated_at: %Schema{
          type: :string,
          description: "Timestamp of last frame update",
          format: "ISO-8601"
        }
      },
      required: [:id, :name, :type],
      example: %{
        id: "3fa85f64-5717-4562-b3fc-2c963f66afa6",
        name: "my-document-frame",
        description: "My document frame",
        type: "zip",
        thumbnail: "https://example.com/thumbnail.jpg",
        asset: %{
          id: "3fa85f64-5717-4562-b3fc-2c963f66afa6",
          name: "Asset",
          type: "frame",
          file: "frame.zip",
          updated_at: "2024-01-15T10:30:00Z",
          inserted_at: "2024-01-15T10:30:00Z"
        },
        fields: [%{name: "field1", type: "text"}],
        meta: %{width: 100, height: 200},
        inserted_at: "2024-01-15T10:30:00Z",
        updated_at: "2024-01-15T10:30:00Z"
      }
    })
  end

  defmodule ShowFrame do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Show Frame",
      description: "Details of a specific frame",
      type: :object,
      properties: %{
        frame: Frame
      },
      example: %{
        frame: %{
          id: "3fa85f64-5717-4562-b3fc-2c963f66afa6",
          name: "my-document-frame",
          description: "My document frame",
          type: "typst",
          thumbnail: "https://example.com/thumbnail.jpg",
          asset: %{
            id: "3fa85f64-5717-4562-b3fc-2c963f66afa6",
            name: "Asset",
            type: "frame",
            file: "frame.zip",
            updated_at: "2024-01-15T10:30:00Z",
            inserted_at: "2024-01-15T10:30:00Z"
          },
          fields: [%{name: "field1", type: "text"}],
          meta: %{width: 100, height: 200},
          inserted_at: "2024-01-15T10:30:00Z",
          updated_at: "2024-01-15T10:30:00Z"
        }
      }
    })
  end

  defmodule FrameIndex do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Frame Index",
      type: :object,
      properties: %{
        frames: %Schema{type: :array, items: Frame},
        page_number: %Schema{type: :integer, description: "Current page number"},
        total_pages: %Schema{type: :integer, description: "Total number of pages"},
        total_entries: %Schema{type: :integer, description: "Total number of frame entries"}
      },
      example: %{
        frames: [
          %{
            id: "3fa85f64-5717-4562-b3fc-2c963f66afa6",
            name: "my-document-frame",
            description: "My document frame",
            type: "typst",
            thumbnail: "https://example.com/thumbnail.jpg",
            asset: %{
              id: "3fa85f64-5717-4562-b3fc-2c963f66afa6",
              name: "Asset",
              type: "frame",
              file: "frame.zip",
              updated_at: "2024-01-15T10:30:00Z",
              inserted_at: "2024-01-15T10:30:00Z"
            },
            fields: [%{name: "field1", type: "text"}],
            meta: %{width: 100, height: 200},
            inserted_at: "2024-01-15T10:30:00Z",
            updated_at: "2024-01-15T10:30:00Z"
          }
        ],
        page_number: 1,
        total_pages: 5,
        total_entries: 25
      }
    })
  end
end
