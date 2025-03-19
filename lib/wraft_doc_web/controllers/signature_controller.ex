defmodule WraftDocWeb.Api.V1.SignatureController do
  use WraftDocWeb, :controller
  use PhoenixSwagger

  plug WraftDocWeb.Plug.AddActionLog

  plug WraftDocWeb.Plug.Authorized,
    request_signature: "document:signature:request",
    sign_document: "document:signature:sign",
    get_document_signatures: "document:signature:show",
    revoke_signature: "document:signature:revoke",
    verify_signature: "document:signature:verify"

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.Documents
  alias WraftDoc.Documents.ESignature
  alias WraftDoc.Documents.Instance
  alias WraftDoc.Documents.Signatures
  alias WraftDoc.Repo

  def swagger_definitions do
    %{
      SignatureRequest:
        swagger_schema do
          title("Signature Request")
          description("Request for digital signature")

          properties do
            counterparty(:map, "Counterparty information", required: true)

            signature_type(:string, "Type of signature",
              required: true,
              enum: ["digital", "electronic", "handwritten"]
            )
          end

          example(%{
            counterparty: %{
              name: "John Doe",
              email: "john.doe@example.com"
            },
            signature_type: "digital"
          })
        end,
      Signature:
        swagger_schema do
          title("Signature")
          description("Digital signature information")

          properties do
            id(:string, "Signature ID", required: true)
            signature_type(:string, "Type of signature")
            signature_date(:string, "Date of signature")
            is_valid(:boolean, "Is the signature valid")
            verification_token(:string, "Token for signature verification")
            instance(:map, "Document instance")
            counterparty(:map, "Counterparty information")
          end
        end,
      SignatureProcess:
        swagger_schema do
          title("Process Signature")
          description("Process a digital signature")

          properties do
            signature_data(:map, "Signature data (could be image data or other format)",
              required: true
            )

            signature_position(:map, "Position in the document")
            ip_address(:string, "IP address of the signer", required: true)
          end
        end
    }
  end

  @doc """
  Request a signature for a document from a counterparty
  """
  swagger_path :request_signature do
    post("/documents/{id}/signatures/request")
    summary("Request document signature")
    description("API to request a signature for a document from a counterparty")

    parameters do
      id(:path, :string, "Document ID", required: true)
      request(:body, Schema.ref(:SignatureRequest), "Signature request details", required: true)
    end

    response(200, "Ok", Schema.ref(:Signature))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not found", Schema.ref(:Error))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
  end

  def request_signature(conn, %{"id" => document_id} = params) do
    current_user = conn.assigns.current_user

    with %Instance{} = instance <- Documents.show_instance(document_id, current_user),
         {:ok, signature} <- Signatures.create_signature_request(instance, current_user, params) do
      render(conn, "signature.json", signature: signature)
    end
  end

  @doc """
  Get all signatures for a document
  """
  swagger_path :get_document_signatures do
    get("/documents/{id}/signatures")
    summary("Get document signatures")
    description("API to get all signatures for a document")

    parameters do
      id(:path, :string, "Document ID", required: true)
    end

    response(200, "Ok", Schema.ref(:Signatures))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not found", Schema.ref(:Error))
  end

  def get_document_signatures(conn, %{"id" => document_id}) do
    current_user = conn.assigns.current_user

    with %Instance{} = _instance <- Documents.show_instance(document_id, current_user),
         signatures <- Signatures.get_document_signatures(document_id) do
      render(conn, "signatures.json", signatures: signatures)
    end
  end

  @doc """
  Process a signature for a document
  """
  swagger_path :sign_document do
    post("/documents/sign/{token}")
    summary("Sign a document")
    description("API to process a signature for a document")

    parameters do
      token(:path, :string, "Signature verification token", required: true)
      signature(:body, Schema.ref(:SignatureProcess), "Signature process details", required: true)
    end

    response(200, "Ok", Schema.ref(:Signature))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not found", Schema.ref(:Error))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
  end

  def sign_document(conn, %{"token" => token} = params) do
    with {:ok, %ESignature{counter_party: counterparty}} <-
           Signatures.verify_signature_by_token(token),
         {:ok, %{signature: signature}} <- Signatures.process_signature(counterparty, params) do
      render(conn, "signature.json", signature: signature)
    end
  end

  @doc """
  Verify a signature
  """
  swagger_path :verify_signature do
    get("/signatures/verify/{token}")
    summary("Verify a signature")
    description("API to verify a signature by token")

    parameters do
      token(:path, :string, "Signature verification token", required: true)
    end

    response(200, "Ok", Schema.ref(:Signature))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not found", Schema.ref(:Error))
  end

  def verify_signature(conn, %{"token" => token}) do
    with {:ok, signature} <- Signatures.verify_signature_by_token(token) do
      render(conn, "signature.json", signature: signature)
    end
  end

  @doc """
  Revoke a signature request
  """
  swagger_path :revoke_signature do
    delete("/documents/{document_id}/signatures/{signature_id}")
    summary("Revoke a signature request")
    description("API to revoke a signature request")

    parameters do
      document_id(:path, :string, "Document ID", required: true)
      signature_id(:path, :string, "Signature ID", required: true)
    end

    response(200, "Ok", Schema.ref(:Signature))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not found", Schema.ref(:Error))
  end

  def revoke_signature(conn, %{"document_id" => document_id, "signature_id" => signature_id}) do
    current_user = conn.assigns.current_user

    with %Instance{} = _instance <- Documents.show_instance(document_id, current_user),
         %ESignature{} = signature <- Signatures.get_signature(signature_id),
         {:ok, %ESignature{}} = deleted_signature <- Repo.delete(signature) do
      render(conn, "signature.json", signature: deleted_signature)
    end
  end
end
