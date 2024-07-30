defmodule WraftDocWeb.Api.V1.InstanceApprovalView do
  use WraftDocWeb, :view

  alias WraftDocWeb.Api.V1.UserView

  def render("approval_history.json", %{history: history}) do
    render_many(history, __MODULE__, "approval.json", as: :document)
  end

  def render("approval.json", %{document: document}) do
    %{
      id: document.id,
      status: document.review_status,
      approver: render_one(document.reviewer, UserView, "user_id_and_name.json", as: :user),
      reviewed_at: document.reviewed_at,
    }
  end
end
