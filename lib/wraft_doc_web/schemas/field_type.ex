defmodule WraftDocWeb.Schemas.FieldType do
  @moduledoc """
  Schema for FieldType request and response
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

  defmodule ValidationRule do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Validation rule",
      description: "A validation rule",
      type: :object,
      properties: %{
        rule: %Schema{type: :string, description: "Validation rule"},
        value: %Schema{
          type: [:string, :number, :boolean, :array],
          description: "Validation value"
        }
      }
    })
  end

  defmodule Validation do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Validation",
      description: "A validation object",
      type: :object,
      properties: %{
        validation: ValidationRule,
        error_message: %Schema{type: :string, description: "Error message when validation fails"}
      },
      example: %{
        validation: %{rule: "required", value: true},
        error_message: "can't be blank"
      }
    })
  end

  defmodule Validations do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Validation array",
      description: "List of validations",
      type: :array,
      items: Validation
    })
  end

  defmodule FieldTypeRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Field type request",
      description: "Field type request",
      type: :object,
      properties: %{
        name: %Schema{type: :string, description: "Name of the field type"},
        description: %Schema{type: :string, description: "Description of the field type"},
        meta: %Schema{type: :object, description: "Meta data of the field type"},
        validations: Validations
      },
      example: %{
        name: "Date",
        description: "A date field",
        meta: %{},
        validations: [
          %{validation: %{rule: "required", value: true}, error_message: "can't be blank"}
        ]
      }
    })
  end

  defmodule FieldType do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Field type",
      description: "A field type.",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "The ID of the field type"},
        name: %Schema{type: :string, description: "Name of the field type"},
        meta: %Schema{type: :object, description: "Meta data of the field type"},
        description: %Schema{type: :string, description: "Description of the field type"},
        validations: Validations,
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
      required: [:id],
      example: %{
        id: "bdf2a17d-c40a-4cd9-affc-d649709a0ed3",
        name: "Date",
        description: "A date field",
        meta: %{},
        validations: [
          %{validation: %{rule: "required", value: true}, error_message: "can't be blank"}
        ],
        updated_at: "2020-01-21T14:00:00Z",
        inserted_at: "2020-02-21T14:00:00Z"
      }
    })
  end

  defmodule FieldTypes do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "All field types",
      description: "All filed types that have been created so far",
      type: :array,
      items: FieldType
    })
  end

  defmodule FieldTypeIndex do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Field Type Index",
      description: "List of field types",
      type: :object,
      properties: %{
        field_types: FieldTypes
      },
      example: %{
        field_types: [
          %{
            id: "1232148nb3478",
            name: "Date",
            description: "A date field",
            updated_at: "2020-01-21T14:00:00Z",
            inserted_at: "2020-02-21T14:00:00Z"
          }
        ]
      }
    })
  end
end
