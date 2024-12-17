defmodule WraftDocWeb.Api.V1.InstanceGuestView do
  use WraftDocWeb, :view

  alias WraftDocWeb.Api.V1.UserView

  def render("collaborator.json", %{collaborator: collaborator, token: token}) do
    %{
      id: collaborator.id,
      content_id: collaborator.content_id,
      state_id: collaborator.state_id,
      role: collaborator.role,
      status: collaborator.status,
      token: token,
      user: render_one(collaborator.user, UserView, "user.json", as: :user)
    }
  end

  def render("collaborators.json", %{collaborators: collaborators}) do
    %{
      collaborators:
        render_many(collaborators, InstanceView, "collaborator.json", as: :collaborator)
    }
  end

  def render("counterparty.json", %{counterparty: counterparty}) do
    %{
      id: counterparty.id,
      name: counterparty.name,
      content: render_one(counterparty.content, InstanceView, "instance.json", as: :content),
      guest_user:
        render_one(counterparty.guest_user, UserView, "guest_user.json", as: :guest_user)
    }
  end

  def render("verify_collaborator.json", %{user: user, token: token}) do
    %{
      user: render_one(user, UserView, "user.json", as: :user),
      token: token
    }
  end
end
