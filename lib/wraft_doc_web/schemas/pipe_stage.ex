defmodule WraftDocWeb.Schemas.PipeStage do
  @moduledoc """
  OpenAPI schemas for Pipe Stage operations
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

  defmodule PipeStageRequestMap do
    @moduledoc """
    Schema for pipe stage request
    """
    OpenApiSpex.schema(%{
      title: "Pipe Stage Request",
      description: "Map with content type, data template and state UUIDs",
      type: :object,
      properties: %{
        content_type_id: %Schema{type: :string, format: :uuid, description: "Content type UUID"},
        data_template_id: %Schema{
          type: :string,
          format: :uuid,
          description: "Data template UUID"
        },
        state_id: %Schema{type: :string, format: :uuid, description: "State UUID"}
      },
      example: %{
        content_type_id: "1232148nb3478",
        data_template_id: "1232148nb3478",
        state_id: "550e8400-e29b-41d4-a716-446655440000"
      }
    })
  end

  defmodule PipeStage do
    @moduledoc """
    Schema for pipe stage response
    """
    OpenApiSpex.schema(%{
      title: "Pipeline Stage",
      description: "One stage in a pipeline",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid, description: "ID of the pipe stage"},
        content_type: %Schema{type: :object, description: "Content type details"},
        data_template: %Schema{type: :object, description: "Data template details"},
        state: %Schema{type: :object, description: "State details"},
        inserted_at: %Schema{
          type: :string,
          format: :"date-time",
          description: "When was the pipe stage inserted"
        },
        updated_at: %Schema{
          type: :string,
          format: :"date-time",
          description: "When was the pipe stage last updated"
        }
      },
      example: %{
        id: "kjasfqjbn",
        updated_at: "2020-01-21T14:00:00Z",
        inserted_at: "2020-02-21T14:00:00Z",
        content_type: %{
          id: "1232148nb3478",
          name: "Offer letter",
          description: "An offer letter",
          prefix: "OFFLET",
          color: "#fffff"
        },
        data_template: %{
          id: "1232148nb3478",
          title: "Template 1",
          title_template: "Letter for [user]",
          data: "Hi [user]"
        },
        state: %{
          id: "state123",
          state: "Draft",
          order: 1
        }
      }
    })
  end

  defmodule PipeStages do
    @moduledoc """
    Schema for list of pipe stages
    """
    OpenApiSpex.schema(%{
      title: "Pipe Stages",
      description: "List of pipe stages",
      type: :array,
      items: PipeStage,
      example: [
        %{
          id: "550e8400-e29b-41d4-a716-446655440000",
          state_id: "550e8400-e29b-41d4-a716-446655440001",
          api_route_id: "550e8400-e29b-41d4-a716-446655440002",
          inserted_at: "2020-01-21T14:00:00Z",
          updated_at: "2020-02-21T14:00:00Z"
        }
      ]
    })
  end

  defmodule DeletedPipeStage do
    @moduledoc """
    Schema for deleted pipe stage response
    """
    OpenApiSpex.schema(%{
      title: "Deleted Pipe Stage",
      description: "Response when a pipe stage is deleted",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid, description: "ID of the pipe stage"},
        inserted_at: %Schema{
          type: :string,
          format: :"date-time",
          description: "When was the pipe stage inserted"
        },
        updated_at: %Schema{
          type: :string,
          format: :"date-time",
          description: "When was the pipe stage last updated"
        }
      },
      example: %{
        id: "kjasfqjbn",
        updated_at: "2020-01-21T14:00:00Z",
        inserted_at: "2020-02-21T14:00:00Z"
      }
    })
  end
end
