defmodule WraftDocWeb.Api.V1.DocumentSignController do
  use WraftDocWeb, :controller
  use PhoenixSwagger

  alias WraftDoc.Integrations.DocuSign

  plug WraftDocWeb.Plug.AddActionLog
  plug WraftDocWeb.Plug.FeatureFlagCheck, feature: :repository

  action_fallback(WraftDocWeb.FallbackController)

  def swagger_definitions do
    %{
      SignerRequest:
        swagger_schema do
          title("Signer")
          description("A recipient who will sign the document")

          properties do
            name(:string, "Name of the signer", required: true)
            email(:string, "Email of the signer", required: true)

            anchor(:string, "Anchor text for signature placement (default: \"SIGN_HERE\")",
              required: false
            )
          end

          example(%{
            name: "John Doe",
            email: "john.doe@example.com",
            anchor: "SIGN_HERE"
          })
        end,
      SendDocumentRequest:
        swagger_schema do
          title("Send Document Request")
          description("Request to send a document for electronic signature")

          properties do
            id(:string, "Document ID to be sent for signature", required: true)

            type(:string, "Signature provider type (\"docusign\" or \"documenso\")",
              required: true
            )

            signers(:array, "List of document signers",
              items: Schema.ref(:SignerRequest),
              required: true
            )
          end

          example(%{
            id: "550e8400-e29b-41d4-a716-446655440000",
            type: "docusign",
            signers: [
              %{
                name: "John Doe",
                email: "john.doe@example.com"
              }
            ]
          })
        end,
      SendDocumentResponse:
        swagger_schema do
          title("Send Document Response")
          description("Response after document is sent for signature")

          properties do
            envelopeId(:string, "Unique ID of the signature envelope")
            status(:string, "Status of the signature request")
            statusDateTime(:string, "Timestamp of the status", format: "date-time")
            uri(:string, "URI to access the envelope")
          end

          example(%{
            envelopeId: "1a2b3c4d-5e6f-7g8h-9i0j-1k2l3m4n5o6p",
            status: "sent",
            statusDateTime: "2023-05-15T09:30:00Z",
            uri: "/envelopes/1a2b3c4d-5e6f-7g8h-9i0j-1k2l3m4n5o6p"
          })
        end
    }
  end

  swagger_path :send_document do
    post("/send_document")
    summary("Send document for electronic signature")

    description(
      "Sends a document to specified recipients for electronic signature using the selected provider (DocuSign or Documenso)"
    )

    parameters do
      body(:body, Schema.ref(:SendDocumentRequest), "Document and signer details", required: true)
    end

    response(201, "Created", Schema.ref(:SendDocumentResponse))
    response(400, "Bad Request")
    response(401, "Unauthorized")
    response(404, "Not Found")
    response(422, "Unprocessable Entity")
    response(500, "Server Error")

    tag("Signature")
  end

  @doc """
  Sends a document for electronic signature.

  This endpoint takes a document ID, signature provider type, and a list of signers,
  then sends the document to those signers using the specified electronic signature service.

  The document must exist in the system and belong to the current organization.
  The type parameter determines which signature provider to use (DocuSign or Documenso).
  The signers parameter should contain a list of recipients with their names and emails.

  Returns the signature request details upon successful creation.
  """
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
