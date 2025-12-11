defmodule WraftDocWeb.Schemas.CollectionForm do
  @moduledoc """
  Schema for CollectionForm request and response
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

  defmodule CollectionFormRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Collection Form",
      description: "Collection Form",
      type: :object,
      properties: %{
        title: %Schema{type: :string, description: "title of the collection form"},
        description: %Schema{type: :string, description: "description for collection form"},
        fields: %Schema{
          type: :array,
          description: "Form fields",
          items: %Schema{
            type: :object,
            properties: %{
              name: %Schema{type: :string, description: "Field name"},
              meta: %Schema{type: :object, description: "Field metadata"},
              field_type: %Schema{type: :string, description: "Field type"}
            }
          }
        }
      },
      example: %{
        title: "Collection Form",
        description: "collection form",
        fields: [
          %{name: "Title", meta: %{color: "black"}, field_type: "string"}
        ]
      }
    })
  end

  defmodule CollectionForm do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Collection Form",
      description: "Collection Form details",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "The ID of the collection form"},
        title: %Schema{type: :string, description: "title of the collection form"},
        description: %Schema{type: :string, description: "Description for title"},
        updated_at: %Schema{type: :string, description: "Updated at", format: "ISO-8601"},
        inserted_at: %Schema{type: :string, description: "Inserted at", format: "ISO-8601"}
      },
      example: %{
        id: "1232148nb3478",
        title: "Collection Form",
        updated_at: "2020-01-21T14:00:00Z",
        inserted_at: "2020-02-21T14:00:00Z"
      }
    })
  end

  defmodule CollectionFormShow do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Show collection form",
      description: "show collection form and its details",
      type: :object,
      properties: %{
        collection_form: CollectionForm
      },
      example: %{
        collection_form: %{
          id: "1232148nb3478",
          title: "Collection Form",
          updated_at: "2020-01-21T14:00:00Z",
          inserted_at: "2020-02-21T14:00:00Z"
        }
      }
    })
  end

  defmodule CollectionFormIndex do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Collection Form Index",
      type: :object,
      properties: %{
        collection_forms: %Schema{
          type: :array,
          items: CollectionFormShow
        },
        page_number: %Schema{type: :integer, description: "Page number"},
        total_pages: %Schema{type: :integer, description: "Total number of pages"},
        total_entries: %Schema{type: :integer, description: "Total number of contents"}
      },
      example: %{
        collection_forms: [
          %{
            collection_form: %{
              description: "collection form",
              id: "6006ce53-edf0-4044-8288-0422ef9ca2d8",
              inserted_at: "2020-01-21T14:00:00Z",
              title: "Collection Form",
              updated_at: "2020-02-21T14:00:00Z"
            }
          }
        ],
        page_number: 1,
        total_pages: 2,
        total_entries: 15
      }
    })
  end
end
