defmodule WraftDocWeb.Schemas.OrganisationField do
  @moduledoc """
  Schema for OrganisationField request and response
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

  defmodule OrganisationFieldRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Organisation Field Request",
      description: "Create organisation field",
      type: :object,
      properties: %{
        name: %Schema{type: :string, description: "Name of the field"},
        field_type_id: %Schema{type: :string, description: "Id of the field type"},
        meta: %Schema{type: :object, description: "Attributes of the field"},
        description: %Schema{type: :string, description: "Field description"}
      },
      required: [:name, :field_type_id],
      example: %{
        name: "position",
        field_type_id: "asdlkne4781234123clk",
        meta: %{"src" => "/img/img.png", "alt" => "Image"},
        description: "text input"
      }
    })
  end

  defmodule OrganisationField do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Organisation field in response",
      description: "Organisation field in respone.",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "ID of Organisation field"},
        name: %Schema{type: :string, description: "Name of Organisation field"},
        meta: %Schema{type: :object, description: "Attributes of the field"},
        field_type: WraftDocWeb.Schemas.FieldType.FieldType
      },
      example: %{
        name: "position",
        field_type_id: "asdlkne4781234123clk",
        meta: %{"src" => "/img/img.png", "alt" => "Image"}
      }
    })
  end

  defmodule OrganisationFields do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Field response array",
      description: "List of field type in response.",
      type: :array,
      items: OrganisationField
    })
  end

  defmodule OrganisationFieldIndex do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Organisation field index",
      type: :object,
      properties: %{
        members: OrganisationField,
        page_number: %Schema{type: :integer, description: "Page number"},
        total_pages: %Schema{type: :integer, description: "Total number of pages"},
        total_entries: %Schema{type: :integer, description: "Total number of contents"}
      }
    })
  end
end
