defmodule WraftDocWeb.Schemas.Health do
  @moduledoc """
  Schema for Health request and response
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

  defmodule HealthResponse do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "HealthResponse",
      description: "Health check response",
      type: :object,
      properties: %{
        status: %Schema{type: :string, description: "Service status", example: "ok"}
      },
      example: %{
        status: "ok"
      }
    })
  end
end
