defmodule WraftDocWeb.Api.V1.DocumentSignController do
  @moduledoc """
  Controller for sending documents for electronic signature
  """
  use WraftDocWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias WraftDoc.Integrations.DocuSign
  alias WraftDocWeb.Schemas

  plug WraftDocWeb.Plug.AddActionLog
  plug WraftDocWeb.Plug.FeatureFlagCheck, feature: :repository

  action_fallback(WraftDocWeb.FallbackController)

  tags(["Signature"])

  @doc """
  Sends a document for electronic signature.

  This endpoint takes a document ID, signature provider type, and a list of signers,
  then sends the document to those signers using the specified electronic signature service.

  The document must exist in the system and belong to the current organization.
  The type parameter determines which signature provider to use (DocuSign or Documenso).
  The signers parameter should contain a list of recipients with their names and emails.

  Returns the signature request details upon successful creation.
  """
  operation(:send_document,
    summary: "Send document for electronic signature",
    description:
      "Sends a document to specified recipients for electronic signature using the selected provider (DocuSign or Documenso)",
    request_body:
      {"Document and signer details", "application/json",
       Schemas.DocumentSign.SendDocumentRequest},
    responses: [
      created: {"Created", "application/json", Schemas.DocumentSign.SendDocumentResponse},
      bad_request: {"Bad Request", "application/json", Schemas.Error},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error},
      not_found: {"Not Found", "application/json", Schemas.Error},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Schemas.Error}
    ]
  )

  @spec send_document(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def send_document(conn, %{"id" => document_id, "type" => type, "signers" => signers}) do
    org_id = conn.assigns.current_user.current_org_id

    with {:ok, integration} <- DocuSign.handle_document(document_id, type, org_id, signers) do
      conn
      |> put_status(:created)
      |> render("show.json", integration: integration)
    end
  end
end
