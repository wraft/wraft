defmodule WraftDocWeb.Schemas.Config do
  @moduledoc """
  Schema for the public runtime config response.
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

  defmodule ConfigResponse do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "ConfigResponse",
      description: "Public runtime configuration for the frontend",
      type: :object,
      properties: %{
        self_hosted: %Schema{
          type: :boolean,
          description: "Whether this deployment runs in self-hosted mode",
          example: false
        }
      },
      example: %{
        self_hosted: false
      }
    })
  end
end
