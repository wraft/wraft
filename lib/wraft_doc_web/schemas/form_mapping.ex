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
        source: %Schema{type: :object, description: "Source field info"}
      },
      example: %{
        destination: %{
          name: "E_name",
          id: "3fa85f64-5717-4562-b3fc-2c963f66afa6"
        },
        source: %{
          id: "3fa85f64-5717-4562-b3fc-2c963f66afa6",
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
      },
      example: %{
        mapping: [
          %{
            destination: %{name: "E_name", id: "3fa85f64-5717-4562-b3fc-2c963f66afa6"},
            source: %{id: "3fa85f64-5717-4562-b3fc-2c963f66afa6", name: "Name"}
          }
        ]
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
        id: %Schema{type: :string, description: "Form Mapping ID"},
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
        id: "3fa85f64-5717-4562-b3fc-2c963f66afa6",
        form_id: "3fa85f64-5717-4562-b3fc-2c963f66afa6",
        pipe_stage_id: "3fa85f64-5717-4562-b3fc-2c963f66afa6",
        inserted_at: "2023-08-21T14:00:00Z",
        updated_at: "2023-08-21T14:00:00Z",
        mapping: [
          %{
            destination: %{
              name: "E_name",
              id: "3fa85f64-5717-4562-b3fc-2c963f66afa6"
            },
            source: %{
              id: "3fa85f64-5717-4562-b3fc-2c963f66afa6",
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
        pipe_stage_id: "3fa85f64-5717-4562-b3fc-2c963f66afa6",
        mapping: [
          %{
            destination: %{
              name: "E_name",
              destination_id: "3fa85f64-5717-4562-b3fc-2c963f66afa6"
            },
            source: %{
              id: "3fa85f64-5717-4562-b3fc-2c963f66afa6",
              name: "Name"
            }
          }
        ]
      }
    })
  end
end
