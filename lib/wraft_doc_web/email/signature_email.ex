defmodule WraftDocWeb.Mailer.SignatureEmail do
  @moduledoc """
  Email module for handling signature-related emails
  """

  import Swoosh.Email
  alias WraftDoc.Documents.Instance
  alias WraftDocWeb.MJML

  @doc """
  Email to request signature from a counterparty
  """
  def signature_request_email(
        to_email,
        %Instance{instance_id: instance_id} = _instance,
        signature_url,
        name
      ) do
    body = %{
      instance_id: instance_id,
      signature_url: signature_url,
      name: name
    }

    new()
    |> to(to_email)
    |> from({"Wraft", sender_email()})
    |> subject("Signature Request: Document #{instance_id}")
    |> html_body(MJML.SignatureRequest.render(body))
  end

  @doc """
  Email to notify document owner when a signature is completed
  """
  def signature_completed_email(
        to_email,
        %Instance{instance_id: instance_id} = _instance,
        signer_name
      ) do
    body = %{
      instance_id: instance_id,
      signer_name: signer_name
    }

    new()
    |> to(to_email)
    |> from({"Wraft", sender_email()})
    |> subject("Signature Completed: Document #{instance_id}")
    |> html_body(MJML.SignatureCompleted.render(body))
  end

  defp sender_email do
    Application.get_env(:wraft_doc, :sender_email)
  end
end
