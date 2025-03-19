defmodule WraftDocWeb.Api.V1.SignatureView do
  use WraftDocWeb, :view

  alias WraftDocWeb.Api.V1.InstanceView
  alias WraftDocWeb.Api.V1.UserView

  def render("signature.json", %{signature: signature}) do
    %{
      id: signature.id,
      signature_type: signature.signature_type,
      signature_date: signature.signature_date,
      is_valid: signature.is_valid,
      verification_token: signature.verification_token,
      instance: render_one(signature.instance, InstanceView, "instance.json", as: :content),
      counter_party:
        render_one(signature.counter_party, __MODULE__, "counterparty.json", as: :counterparty),
      user: render_one(signature.user, UserView, "user.json", as: :user),
      created_at: signature.inserted_at,
      updated_at: signature.updated_at
    }
  end

  def render("signatures.json", %{signatures: signatures}) do
    %{
      signatures: render_many(signatures, __MODULE__, "signature.json", as: :signature)
    }
  end

  def render("counterparty.json", %{counterparty: counterparty}) do
    %{
      id: counterparty.id,
      name: counterparty.name,
      email: counterparty.email,
      signature_status: counterparty.signature_status,
      signature_date: counterparty.signature_date
    }
  end

  def render("counterparties.json", %{counterparties: counterparties}) do
    %{
      counterparties:
        render_many(counterparties, __MODULE__, "counterparty.json", as: :counterparty)
    }
  end
end
