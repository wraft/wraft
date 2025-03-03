defmodule WraftDocWeb.Api.V1.DashboardController do
  use WraftDocWeb, :controller
  use PhoenixSwagger

  plug WraftDocWeb.Plug.AddActionLog

  plug WraftDocWeb.Plug.Authorized,
    dashboard_stats: "dashboard:show"

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
end
