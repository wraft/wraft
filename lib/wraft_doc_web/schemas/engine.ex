defmodule WraftDocWeb.Schemas.Engine do
  @moduledoc """
  Schema for Engine request and response
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

  defmodule Engine do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Render engine",
      description: "A render engine to be used for document generation",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "The ID of the engine"},
        name: %Schema{type: :string, description: "Engine's name"},
        api_route: %Schema{type: :string, description: "API route to be used"},
        inserted_at: %Schema{
          type: :string,
          description: "When was the engine inserted",
          format: "ISO-8601"
        },
        updated_at: %Schema{
          type: :string,
          description: "When was the engine last updated",
          format: "ISO-8601"
        }
      },
      required: [:id, :name],
      example: %{
        id: "1232148nb3478",
        name: "Pandoc",
        api_route: "",
        updated_at: "2020-01-21T14:00:00Z",
        inserted_at: "2020-02-21T14:00:00Z"
      }
    })
  end

  defmodule Engines do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Engines",
      description: "All engines that have been created",
      type: :array,
      items: Engine
    })
  end

  defmodule EngineIndex do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Engine Index",
      description: "List of engines",
      type: :object,
      properties: %{
        engines: Engines,
        page_number: %Schema{type: :integer, description: "Page number"},
        total_pages: %Schema{type: :integer, description: "Total number of pages"},
        total_entries: %Schema{type: :integer, description: "Total number of contents"}
      },
      example: %{
        engines: [
          %{
            id: "1232148nb3478",
            name: "Pandoc",
            api_route: "",
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
end
