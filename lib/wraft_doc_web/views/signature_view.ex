defmodule WraftDocWeb.Api.V1.SignatureView do
  use WraftDocWeb, :view

  # alias WraftDocWeb.Api.V1.InstanceView
  # alias WraftDocWeb.Api.V1.UserView
  alias WraftDoc.Client.Minio

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
      color_rgb: counterparty.color_rgb,
      signature_image: generate_url(counterparty),
      signature_status: counterparty.signature_status,
      signed_file: Minio.generate_url(counterparty.signed_file),
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

  def render("signed_pdf.json", %{url: url, sign_status: sign_status}) do
    %{
      signed_pdf_url: url,
      sign_status: sign_status,
      message: "Signature applied successfully"
    }
  end

  def render("content_sign_settings.json", %{settings: settings}) do
    %{
      signature_type: settings["signature_type"],
      sign_order_enabled: settings["sign_order_enabled"],
      day_to_complete: settings["day_to_complete"],
      reminder_enabled: settings["reminder_enabled"],
      reminder_interval_days: settings["reminder_interval_days"],
      cc_recipients: settings["cc_recipients"]
    }
  end

  def generate_url(%{signature_image: file} = signature) do
    WraftDocWeb.SignatureUploader.url({file, signature}, signed: true)
  end
end
