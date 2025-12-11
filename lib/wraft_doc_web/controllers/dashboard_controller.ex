defmodule WraftDocWeb.Api.V1.DashboardController do
  use WraftDocWeb, :controller
  use OpenApiSpex.ControllerSpecs

  plug WraftDocWeb.Plug.AddActionLog

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.Documents
  alias WraftDocWeb.Schemas.Dashboard, as: DashboardSchema
  alias WraftDocWeb.Schemas.Error

  tags(["Dashboard"])

  operation(:dashboard_stats,
    summary: "Get dashboard stats",
    description:
      "Get dashboard stats , e.g. total number of documents, daily documents or pending approvals",
    responses: [
      ok: {"OK", "application/json", DashboardSchema.DashboardStatsResponse},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  @spec dashboard_stats(Plug.Conn.t(), map) :: Plug.Conn.t()
  def dashboard_stats(conn, _params) do
    current_user = conn.assigns.current_user

    with stats <- Documents.get_dashboard_stats(current_user) do
      render(conn, "dashboard_stats.json", stats: stats)
    end
  end

  operation(:documents_by_content_type,
    summary: "Get documents by content type",
    description: "Get document counts grouped by content type for the current organization",
    responses: [
      ok: {"OK", "application/json", DashboardSchema.DocumentsByContentTypeResponse},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  @spec documents_by_content_type(Plug.Conn.t(), map) :: Plug.Conn.t()
  def documents_by_content_type(conn, _params) do
    current_user = conn.assigns.current_user

    with data <- Documents.get_documents_by_content_type(current_user) do
      render(conn, "documents_by_content_type.json", data: data)
    end
  end
end
