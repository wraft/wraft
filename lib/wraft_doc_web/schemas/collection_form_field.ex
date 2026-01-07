defmodule WraftDocWeb.Schemas.CollectionFormField do
  @moduledoc """
  Schema for CollectionFormField request and response
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

  defmodule CollectionFormFieldRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Collection Form Field Request",
      description: "Collection Form Field",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "The ID of the collection form field"},
        name: %Schema{type: :string, description: "title of the collection form field"},
        description: %Schema{type: :string, description: "description for collection form field"}
      },
      required: [:id],
      example: %{
        name: "Collection Form Field",
        description: "collection form",
        collection_form_id: "collection form id"
      }
    })
  end

  defmodule CollectionFormField do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Collection Form Field",
      description: "Collection Form Field details",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "The ID of the collection form field"},
        name: %Schema{type: :string, description: "name of the collection form field"},
        description: %Schema{type: :string, description: "Description for name"},
        updated_at: %Schema{type: :string, description: "Updated at", format: "ISO-8601"},
        inserted_at: %Schema{type: :string, description: "Inserted at", format: "ISO-8601"}
      },
      example: %{
        id: "1232148nb3478",
        name: "Collection Form Field",
        updated_at: "2020-01-21T14:00:00Z",
        inserted_at: "2020-02-21T14:00:00Z"
      }
    })
  end

  defmodule CollectionFormFieldShow do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Show collection form field",
      description: "show collection form field and its details",
      type: :object,
      properties: %{
        collection_form_field: CollectionFormField
      },
      example: %{
        collection_form_field: %{
          id: "1232148nb3478",
          name: "Collection Form Field",
          updated_at: "2020-01-21T14:00:00Z",
          inserted_at: "2020-02-21T14:00:00Z"
        }
      }
    })
  end
end
