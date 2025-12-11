defmodule WraftDocWeb.Schemas.FormMapping do
  @moduledoc """
  Schema for FormMapping request and response
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

  defmodule MappingItem do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Mapping Item",
      description: "A single mapping item",
      type: :object,
      properties: %{
        destination: %Schema{type: :object, description: "Destination field info"},
        source: %Schema{type: :object, description: "Source field info"},
        id: %Schema{type: :string, description: "Mapping ID"}
      },
      example: %{
        id: "e63d02aa-6ea6-4e10-87aa-61061e7557eb",
        destination: %{
          name: "E_name",
          id: "992c50b2-c586-449f-b298-78d59d8ab81c"
        },
        source: %{
          id: "992c50b2-c586-449f-b298-78d59d8ab81c",
          name: "Name"
        }
      }
    })
  end

  defmodule Mapping do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Form mapping",
      description: "Mapping body",
      type: :object,
      properties: %{
        mapping: %Schema{type: :array, description: "Mapping body", items: MappingItem}
      }
    })
  end

  defmodule FormMappingResponse do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Wraft Form mapping response",
      description: "Form mapping response body",
      type: :object,
      properties: %{
        form_id: %Schema{type: :string, description: "Form id"},
        pipe_stage_id: %Schema{type: :string, description: "Pipe stage id"},
        mapping: %Schema{type: :array, items: MappingItem},
        inserted_at: %Schema{
          type: :string,
          description: "When was the mapping created",
          format: "ISO-8601"
        },
        updated_at: %Schema{
          type: :string,
          description: "When was the mapping last updated",
          format: "ISO-8601"
        }
      },
      example: %{
        form_id: "992c50b2-c586-449f-b298-78d59d8ab81c",
        pipe_stage_id: "992c50b2-c586-449f-b298-78d59d8ab81c",
        inserted_at: "2023-08-21T14:00:00Z",
        updated_at: "2023-08-21T14:00:00Z",
        mapping: [
          %{
            id: "e63d02aa-6ea6-4e10-87aa-61061e7557eb",
            destination: %{
              name: "E_name",
              id: "992c50b2-c586-449f-b298-78d59d8ab81c"
            },
            source: %{
              id: "992c50b2-c586-449f-b298-78d59d8ab81c",
              name: "Name"
            }
          }
        ]
      }
    })
  end

  defmodule FormMapping do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Wraft Form mapping",
      description: "Form mapping body to create",
      type: :object,
      properties: %{
        form_id: %Schema{type: :string, description: "Form id"},
        pipe_stage_id: %Schema{type: :string, description: "Pipe stage id"},
        mapping: %Schema{type: :array, items: MappingItem}
      },
      required: [:pipe_stage_id],
      example: %{
        pipe_stage_id: "0043bde9-3903-4cb7-b898-cd4d7cbe99bb",
        mapping: [
          %{
            destination: %{
              name: "E_name",
              destination_id: "992c50b2-c586-449f-b298-78d59d8ab81c"
            },
            source: %{
              id: "992c50b2-c586-449f-b298-78d59d8ab81c",
              name: "Name"
            }
          }
        ]
      }
    })
  end
end
