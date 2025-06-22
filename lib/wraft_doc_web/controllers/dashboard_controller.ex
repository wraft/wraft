defmodule WraftDocWeb.Api.V1.DashboardController do
  use WraftDocWeb, :controller
  use PhoenixSwagger

  plug WraftDocWeb.Plug.AddActionLog

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.Documents

  def swagger_definitions do
    %{
      DashboardStatsResponse:
        swagger_schema do
          title("Dashboard stats")
          description("Dashboard stats")

          properties do
            total_documents(:integer, "Total number of documents")
            today_documents(:integer, "Total number of documents today")
            pending_approvals(:integer, "Total number of pending approvals")
          end

          example(%{
            total_documents: 50,
            today_documents: 10,
            pending_approvals: 5
          })
        end,
      DocumentsByContentTypeResponse:
        swagger_schema do
          title("Documents by content type")
          description("Document counts grouped by content type")

          properties do
            data(:array, "Array of document counts by content type",
              items: Schema.ref(:DocumentCountByType)
            )
          end

          example(%{
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
          })
        end,
      DocumentCountByType:
        swagger_schema do
          title("Document count by type")
          description("Document count for a specific content type")

          properties do
            id(:string, "Content type ID", required: true)
            name(:string, "Content type name", required: true)
            color(:string, "Content type color (hex code)", required: false)
            count(:integer, "Number of documents", required: true)
          end

          example(%{
            id: "123e4567-e89b-12d3-a456-426614174000",
            name: "Contract",
            color: "#FF5733",
            count: 25
          })
        end
    }
  end

  @doc """
  Get dashboard stats
  """
  swagger_path :dashboard_stats do
    get("/dashboard_stats")
    summary("Get dashboard stats")

    description(
      "Get dashboard stats , e.g. total number of documents, daily documents or pending approvals"
    )

    response(200, "OK", Schema.ref(:DashboardStatsResponse))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec dashboard_stats(Plug.Conn.t(), map) :: Plug.Conn.t()
  def dashboard_stats(conn, _params) do
    current_user = conn.assigns.current_user

    with stats <- Documents.get_dashboard_stats(current_user) do
      render(conn, "dashboard_stats.json", stats: stats)
    end
  end

  @doc """
  Get documents by content type
  """
  swagger_path :documents_by_content_type do
    get("/documents/by_content_type")
    summary("Get documents by content type")

    description("Get document counts grouped by content type for the current organization")

    response(200, "OK", Schema.ref(:DocumentsByContentTypeResponse))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec documents_by_content_type(Plug.Conn.t(), map) :: Plug.Conn.t()
  def documents_by_content_type(conn, _params) do
    current_user = conn.assigns.current_user

    with data <- Documents.get_documents_by_content_type(current_user) do
      render(conn, "documents_by_content_type.json", data: data)
    end
  end
end
