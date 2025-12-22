defmodule WraftDocWeb.Schemas.Dashboard do
  @moduledoc """
  Schema for Dashboard request and response
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

  defmodule DashboardStatsResponse do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Dashboard stats",
      description: "Dashboard stats",
      type: :object,
      properties: %{
        total_documents: %Schema{type: :integer, description: "Total number of documents"},
        today_documents: %Schema{type: :integer, description: "Total number of documents today"},
        pending_approvals: %Schema{
          type: :integer,
          description: "Total number of pending approvals"
        }
      },
      example: %{
        total_documents: 50,
        today_documents: 10,
        pending_approvals: 5
      }
    })
  end

  defmodule DocumentCountByType do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Document count by type",
      description: "Document count for a specific content type",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "Content type ID"},
        name: %Schema{type: :string, description: "Content type name"},
        color: %Schema{type: :string, description: "Content type color (hex code)"},
        count: %Schema{type: :integer, description: "Number of documents"}
      },
      required: [:id, :name, :count],
      example: %{
        id: "123e4567-e89b-12d3-a456-426614174000",
        name: "Contract",
        color: "#FF5733",
        count: 25
      }
    })
  end

  defmodule DocumentsByContentTypeResponse do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Documents by content type",
      description: "Document counts grouped by content type",
      type: :object,
      properties: %{
        data: %Schema{
          type: :array,
          description: "Array of document counts by content type",
          items: DocumentCountByType
        }
      },
      example: %{
        data: [
          %{
            id: "123e4567-e89b-12d3-a456-426614174000",
            name: "Contract",
            color: "#FF5733",
            count: 25
          },
          %{
            id: "123e4567-e89b-12d3-a456-426614174001",
            name: "Invoice",
            color: "#33FF57",
            count: 15
          },
          %{
            id: "123e4567-e89b-12d3-a456-426614174002",
            name: "Report",
            color: "#3357FF",
            count: 10
          }
        ]
      }
    })
  end
end
