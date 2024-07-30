defmodule WraftDocWeb.Api.V1.DashboardView do
  use WraftDocWeb, :view

  def render("dashboard_stats.json", %{stats: stats}) do
    %{
      total_documents: stats.total_documents,
      daily_documents: stats.daily_documents,
      pending_approvals: stats.pending_approvals
    }
  end
end
