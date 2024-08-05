defmodule WraftDocWeb.Api.V1.InstanceApprovalView do
  use WraftDocWeb, :view

  alias WraftDocWeb.Api.V1.{
    StateView,
    UserView,
  }

  def render("approval_history.json", %{history: history}) do
    render_many(history, __MODULE__, "approval.json", as: :document)
  end

  def render("approval.json", %{document: document}) do
    %{
      id: document.id,
      review_status: document.review_status,
      approver: render_one(document.reviewer, UserView, "user_id_and_name.json", as: :user),
      to_state: render_one(document.to_state, StateView, "state.json", as: :state),
      reviewed_at: document.reviewed_at,
    }
  end
end
