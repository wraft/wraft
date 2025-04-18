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
      email: counterparty.email,
      signature_status: counterparty.signature_status,
      signature_date: counterparty.signature_date,
      created_at: counterparty.inserted_at,
      updated_at: counterparty.updated_at
    }
  end

  def render("verify_collaborator.json", %{user: user, token: token, role: role}) do
    %{
      user: render_one(user, UserView, "user.json", as: :user),
      token: token,
      role: role
    }
  end

  def render("verify_signer.json", %{counter_party: counter_party, token: token}) do
    %{
      counterparty:
        render_one(counter_party, InstanceGuestView, "counterparty.json", as: :counterparty),
      token: token
    }
  end
end
