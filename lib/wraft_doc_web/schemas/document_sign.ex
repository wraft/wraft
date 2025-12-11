defmodule WraftDocWeb.Schemas.DocumentSign do
  @moduledoc """
  OpenAPI schemas for Document Signature operations
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

  defmodule SignerRequest do
    @moduledoc """
    Schema for a signer who will sign the document
    """
    OpenApiSpex.schema(%{
      title: "Signer",
      description: "A recipient who will sign the document",
      type: :object,
      properties: %{
        name: %Schema{type: :string, description: "Name of the signer"},
        email: %Schema{type: :string, format: :email, description: "Email of the signer"},
        anchor: %Schema{
          type: :string,
          description: "Anchor text for signature placement (default: \"SIGN_HERE\")"
        }
      },
      required: [:name, :email],
      example: %{
        name: "John Doe",
        email: "john.doe@example.com",
        anchor: "SIGN_HERE"
      }
    })
  end

  defmodule SendDocumentRequest do
    @moduledoc """
    Schema for sending a document for electronic signature
    """
    OpenApiSpex.schema(%{
      title: "Send Document Request",
      description: "Request to send a document for electronic signature",
      type: :object,
      properties: %{
        id: %Schema{
          type: :string,
          format: :uuid,
          description: "Document ID to be sent for signature"
        },
        type: %Schema{
          type: :string,
          enum: ["docusign", "documenso"],
          description: "Signature provider type (\"docusign\" or \"documenso\")"
        },
        signers: %Schema{
          type: :array,
          description: "List of document signers",
          items: SignerRequest
        }
      },
      required: [:id, :type, :signers],
      example: %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        type: "docusign",
        signers: [
          %{
            name: "John Doe",
            email: "john.doe@example.com"
          }
        ]
      }
    })
  end

  defmodule SendDocumentResponse do
    @moduledoc """
    Schema for response after document is sent for signature
    """
    OpenApiSpex.schema(%{
      title: "Send Document Response",
      description: "Response after document is sent for signature",
      type: :object,
      properties: %{
        envelopeId: %Schema{
          type: :string,
          description: "Unique ID of the signature envelope"
        },
        status: %Schema{
          type: :string,
          description: "Status of the signature request"
        },
        statusDateTime: %Schema{
          type: :string,
          format: :"date-time",
          description: "Timestamp of the status"
        },
        uri: %Schema{
          type: :string,
          description: "URI to access the envelope"
        }
      },
      example: %{
        envelopeId: "1a2b3c4d-5e6f-7g8h-9i0j-1k2l3m4n5o6p",
        status: "sent",
        statusDateTime: "2023-05-15T09:30:00Z",
        uri: "/envelopes/1a2b3c4d-5e6f-7g8h-9i0j-1k2l3m4n5o6p"
      }
    })
  end
end
