defmodule WraftDocWeb.Api.V1.SignatureView do
  use WraftDocWeb, :view

  # alias WraftDocWeb.Api.V1.InstanceView
  # alias WraftDocWeb.Api.V1.UserView

  def render("signature.json", %{signature: signature}) do
    %{
      id: signature.id,
      signature_type: signature.signature_type,
      signature_date: signature.signature_date,
      signature_data: signature.signature_data,
      signature_position: signature.signature_position,
      is_valid: signature.is_valid,
      # content: render_one(signature.content, InstanceView, "instance.json", as: :instance),
      counter_party:
        render_one(signature.counter_party, __MODULE__, "counterparty.json", as: :counterparty),
      # user: render_one(signature.user, UserView, "user.json", as: :user),
      signature_url: generate_url(signature),
      created_at: signature.inserted_at,
      updated_at: signature.updated_at
    }
  end

  def render("signatures.json", %{signatures: signatures, document_url: document_url}) do
    %{
      document_url: document_url,
      signatures: render_many(signatures, __MODULE__, "signature.json", as: :signature)
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

  def render("counterparties.json", %{counterparties: counterparties}) do
    %{
      counterparties:
        render_many(counterparties, __MODULE__, "counterparty.json", as: :counterparty)
    }
  end

  def render("email.json", %{info: info}), do: %{info: info}
  def render("error.json", %{error: error}), do: %{error: error}

  def render("signed_pdf.json", %{url: url}) do
    %{
      signed_pdf_url: url,
      message: "Visual signature applied successfully"
    }
  end

  def generate_url(%{file: file} = signature) do
    WraftDocWeb.SignatureUploader.url({file, signature}, signed: true)
  end
end
