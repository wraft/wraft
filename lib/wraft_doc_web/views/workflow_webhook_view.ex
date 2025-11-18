defmodule WraftDocWeb.Api.V1.WorkflowWebhookView do
  use WraftDocWeb, :view

  def render("show.json", %{run: run}) do
    # Reuse WorkflowRunView for consistency
    WraftDocWeb.Api.V1.WorkflowRunView.render("show.json", run: run)
  end
end
