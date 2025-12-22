defmodule WraftDocWeb.Schemas.Error do
  @moduledoc """
  Schema for Error request and response
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "Error",
    description: "Error response",
    type: :object,
    properties: %{
      errors: %Schema{
        type: :object,
        description: "Map of field names to error messages",
        additionalProperties: %Schema{
          type: :array,
          items: %Schema{type: :string}
        }
      },
      message: %Schema{type: :string, description: "Error message"}
    },
    example: %{
      message: "Something went wrong",
      errors: %{
        detail: ["Not found"]
      }
    }
  })
end
