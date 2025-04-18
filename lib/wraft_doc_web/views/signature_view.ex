defmodule WraftDocWeb.Api.V1.SignatureView do
  use WraftDocWeb, :view

  alias WraftDocWeb.Api.V1.InstanceGuestView
  alias WraftDocWeb.Api.V1.InstanceView
  alias WraftDocWeb.Api.V1.UserView

  def render("signature.json", %{signature: signature}) do
    %{
      id: signature.id,
      signature_type: signature.signature_type,
      verification_token: signature.verification_token,
      signature_date: signature.signature_date,
      signature_data: signature.signature_data,
      signature_position: signature.signature_position,
      ip_address: signature.ip_address,
      is_valid: signature.is_valid,
      content: render_one(signature.content, InstanceView, "instance.json", as: :instance),
      counter_party:
        render_one(signature.counter_party, InstanceGuestView, "counterparty.json",
          as: :counterparty
        ),
      user: render_one(signature.user, UserView, "user.json", as: :user),
      signature_url: generate_url(signature),
      created_at: signature.inserted_at,
      updated_at: signature.updated_at
    }
  end

  def render("signatures.json", %{signatures: signatures}) do
    %{
      signatures: render_many(signatures, __MODULE__, "signature.json", as: :signature)
    }
  end

  def render("counterparties.json", %{counterparties: counterparties}) do
    %{
      counterparties:
        render_many(counterparties, InstanceGuestView, "counterparty.json", as: :counterparty)
    }
  end

  def generate_url(%{file: file} = signature) do
    WraftDocWeb.SignatureUploader.url({file, signature}, signed: true)
  end
end
