defmodule WraftDocWeb.Schemas.Frame do
  @moduledoc """
  Schema for Frame request and response
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

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
        id: "123e4567-e89b-12d3-a456-426614174000",
        name: "my-document-frame",
        description: "My document frame",
        type: "zip",
        inserted_at: "2024-01-15T10:30:00Z",
        updated_at: "2024-01-15T10:30:00Z"
      }
    })
  end

  defmodule UpdateFrame do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Update Frame",
      description: "Updated Frame resource",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "Unique identifier for the frame"},
        name: %Schema{type: :string, description: "Name of the frame"},
        type: %Schema{type: :string, description: "Type of the frame"},
        description: %Schema{type: :string, description: "Description of the frame"},
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
        id: "123e4567-e89b-12d3-a456-426614174000",
        name: "my-document-frame",
        description: "My document frame",
        type: "zip",
        inserted_at: "2024-01-15T10:30:00Z",
        updated_at: "2024-01-15T10:30:00Z"
      }
    })
  end

  defmodule Frames do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "All Frames",
      description: "All frames created under current user's organisation",
      type: :array,
      items: UpdateFrame
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
        id: "123e4567-e89b-12d3-a456-426614174000",
        name: "my-document-frame",
        description: "My document frame",
        type: "typst",
        inserted_at: "2024-01-15T10:30:00Z",
        updated_at: "2024-01-15T10:30:00Z"
      }
    })
  end

  defmodule FrameIndex do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Frame Index",
      type: :object,
      properties: %{
        frames: Frames,
        page_number: %Schema{type: :integer, description: "Current page number"},
        total_pages: %Schema{type: :integer, description: "Total number of pages"},
        total_entries: %Schema{type: :integer, description: "Total number of frame entries"}
      },
      example: %{
        frames: [
          %{
            id: "123e4567-e89b-12d3-a456-426614174000",
            name: "my-document-frame",
            description: "My document frame",
            type: "typst",
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
