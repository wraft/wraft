defmodule WraftDocWeb.Api.V1.InstanceGuestView do
  use WraftDocWeb, :view

  alias WraftDocWeb.Api.V1.UserView

  def render("collaborator.json", %{collaborator: collaborator}) do
    %{
      id: collaborator.id,
      content_id: collaborator.content_id,
      state_id: collaborator.state_id,
      role: collaborator.role,
      status: collaborator.status,
      user: render_one(collaborator.user, UserView, "user.json", as: :user)
    }
  end

  def render("collaborators.json", %{collaborators: collaborators}) do
    %{
      collaborators:
        render_many(collaborators, __MODULE__, "collaborator.json", as: :collaborator)
    }
  end

  def render("counterparty.json", %{counterparty: counterparty}) do
    %{
      id: counterparty.id,
      name: counterparty.name,
      content: render_one(counterparty.content, InstanceView, "instance.json", as: :content),
      guest_user: render_one(counterparty.user, UserView, "guest_user.json", as: :guest_user)
    }
  end

  def render("verify_collaborator.json", %{user: user, token: token, role: role}) do
    %{
      user: render_one(user, UserView, "user.json", as: :user),
      token: token,
      role: role
    }
  end
end
