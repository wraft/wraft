defmodule WraftDocWeb.Schemas.Search do
  @moduledoc """
  Schema for Search request and response
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

  defmodule SearchResponse do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Search Results",
      description: "Results returned from the search operation",
      type: :object,
      properties: %{
        found: %Schema{type: :integer, description: "Total number of results found"},
        page: %Schema{type: :integer, description: "Current page number"},
        request_params: %Schema{
          type: :object,
          description: "Parameters used in the search request"
        },
        hits: %Schema{
          type: :array,
          description: "Search results",
          items: %Schema{
            type: :object,
            properties: %{
              document: %Schema{type: :object, description: "Document data"},
              highlights: %Schema{
                type: :array,
                description: "Highlighted search terms",
                items: %Schema{type: :object}
              }
            }
          }
        }
      },
      example: %{
        hits: [
          %{
            document: %{
              id: "124",
              title: "Sample Document"
            },
            highlights: [
              %{field: "title", snippet: "Sample <mark>Document</mark>"}
            ]
          }
        ],
        found: 1,
        page: 1,
        request_params: %{
          q: "sample",
          collection: "documents"
        }
      }
    })
  end

  defmodule ReindexResponse do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Reindex Response",
      description: "Response for reindexing operation",
      type: :object,
      properties: %{
        status: %Schema{type: :string, description: "Operation status"},
        message: %Schema{type: :string, description: "Operation message"}
      },
      example: %{
        status: "success",
        message: "Collections initialized and data reindexed"
      }
    })
  end
end
