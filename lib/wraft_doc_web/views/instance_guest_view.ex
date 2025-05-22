defmodule WraftDocWeb.Api.V1.InstanceGuestView do
  use WraftDocWeb, :view

  alias WraftDocWeb.Api.V1.SignatureView
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

  def render("verify_collaborator.json", %{user: user, token: token, role: role}) do
    %{
      user: render_one(user, UserView, "user.json", as: :user),
      token: token,
      role: role
    }
  end

  def render("verify_signer.json", %{
        counter_party: counter_party,
        token: session_token,
        role: role
      }) do
    %{
      counterparty:
        render_one(counter_party, SignatureView, "counterparty.json", as: :counterparty),
      token: session_token,
      role: role
    }
  end
end
