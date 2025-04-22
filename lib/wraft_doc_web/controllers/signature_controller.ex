defmodule WraftDocWeb.Api.V1.SignatureController do
  use WraftDocWeb, :controller
  use PhoenixSwagger

  plug WraftDocWeb.Plug.AddActionLog

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.Account
  alias WraftDoc.Account.User
  alias WraftDoc.AuthTokens
  alias WraftDoc.AuthTokens.AuthToken
  alias WraftDoc.CounterParties
  alias WraftDoc.CounterParties.CounterParty
  alias WraftDoc.Documents
  alias WraftDoc.Documents.ESignature
  alias WraftDoc.Documents.Instance
  alias WraftDoc.Documents.Signatures

  def swagger_definitions do
    %{
      CounterPartyRequest:
        swagger_schema do
          title("Counter Party Request")
          description("Request for a counter party to sign a document")

          properties do
            name(:string, "Name of the signatory", required: true)
            email(:string, "Email of the signatory", required: true)
          end

          example(%{
            name: "John Doe",
            email: "john.doe@example.com"
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
      Signatures:
        swagger_schema do
          title("Signatures")
          description("List of signatures")

          properties do
            data(
              Schema.array(:object),
              "List of signatures",
              items: Schema.ref(:Signature)
            )
          end

          example(%{
            signatures: [
              %{
                id: "123e4567-e89b-12d3-a456-426614174000",
                signature_type: "digital",
                signature_date: "2023-01-01T00:00:00Z",
                is_valid: true,
                verification_token: "abc123",
                instance: %{
                  id: "123e4567-e89b-12d3-a456-426614174000",
                  title: "Document Title"
                },
                counter_party: %{
                  name: "John Doe",
                  email: "john.doe@example.com"
                }
              }
            ]
          })
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
            file(:string, "URL of the uploaded file")
            token(:string, "Verification token", required: true)

            signature_type(:string, "Type of signature",
              required: true,
              enum: ["digital", "electronic", "handwritten"]
            )
          end

          example(%{
            file: "/signature.pdf",
            signature_type: "digital",
            is_valid: true,
            verification_token: "abc123",
            signature_data: %{},
            signature_position: %{
              "x" => 100,
              "y" => 200
            }
          })
        end
    }
  end

  @doc """
  Request a signature for a document from a counterparty
  """
  swagger_path :add_counterparty do
    post("/contents/{id}/add_counterparty")
    summary("Request document signature from counterparty")
    description("API to request a signature for a document from a counterparty")

    parameters do
      id(:path, :string, "Document ID", required: true)

      request(:body, Schema.ref(:CounterPartyRequest), "Signature request details",
        required: true
      )
    end

    response(200, "Ok", Schema.ref(:Signature))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not found", Schema.ref(:Error))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
  end

  @spec add_counterparty(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def add_counterparty(conn, %{"id" => document_id, "email" => _email} = params) do
    current_user = conn.assigns.current_user

    with %Instance{} = instance <- Documents.show_instance(document_id, current_user),
         %User{} = invited_user <- Account.get_or_create_guest_user(params),
         %CounterParty{} = counterparty <-
           CounterParties.get_or_create_counter_party(instance, params, invited_user) do
      render(conn, "counterparty.json", counterparty: counterparty)
    end
  end

  @doc """
  List counterparties for a document
  """
  swagger_path :list_counterparties do
    get("/contents/{id}/counterparties")
    summary("List document counterparties")
    description("API to list all counterparties for a document")

    parameters do
      id(:path, :string, "Document ID", required: true)
    end

    response(200, "Ok", Schema.ref(:CounterPartiesList))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not found", Schema.ref(:Error))
  end

  @spec list_counterparties(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def list_counterparties(conn, %{"id" => document_id}) do
    current_user = conn.assigns.current_user

    with %Instance{} = _instance <- Documents.show_instance(document_id, current_user),
         counterparties <- CounterParties.get_document_counterparties(document_id) do
      render(conn, "counterparties.json", counterparties: counterparties)
    end
  end

  @doc """
  Request a signature for a document from a counterparty
  """
  swagger_path :request_signature do
    post("/contents/{id}/request_signature")
    summary("Request document signature from counterparty by email")
    description("API to request a signature for a document from a counterparty by email")

    parameters do
      id(:path, :string, "Document ID", required: true)

      counterparty_id(
        :query,
        :string,
        "Counter Party ID (optional). If not provided, sends to all pending counterparties."
      )
    end

    response(200, "Ok", Schema.ref(:Signature))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not found", Schema.ref(:Error))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
  end

  @spec request_signature(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def request_signature(
        conn,
        %{"id" => document_id, "counterparty_id" => counter_party_id} = _params
      ) do
    current_user = conn.assigns.current_user

    with %Instance{} = instance <- Documents.show_instance(document_id, current_user),
         %CounterParty{email: email, signature_status: :pending} = counter_party <-
           CounterParties.get_counterparty(document_id, counter_party_id),
         {:ok, %AuthToken{value: token}} <-
           AuthTokens.create_signer_invite_token(instance, email),
         %ESignature{} <- Signatures.create_signature(instance, current_user, counter_party),
         {:ok, %Oban.Job{}} <- Signatures.signature_request_email(instance, counter_party, token) do
      render(conn, "email.json", info: "Signature request email sent to #{counter_party.email}")
    else
      %CounterParty{} ->
        render(conn, "error.json", error: "Counterparty already accepted the document access")
    end
  end

  @spec request_signature(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def request_signature(conn, %{"id" => document_id}) do
    current_user = conn.assigns.current_user

    with %Instance{} = instance <- Documents.show_instance(document_id, current_user),
         counter_parties <- Signatures.get_document_pending_signatures(document_id),
         :ok <- Signatures.create_signature(instance, current_user, counter_parties) do
      Signatures.signature_request_email(instance, counter_parties)

      render(conn, "email.json",
        info: "Signature request email sent to #{length(counter_parties)} counterparties"
      )
    end
  end

  @doc """
  Get all signatures for a document
  """
  swagger_path :get_document_signatures do
    get("/contents/{id}/signatures")
    summary("Get document signatures")
    description("API to get all signatures for a document")

    parameters do
      id(:path, :string, "Document ID", required: true)
    end

    response(200, "Ok", Schema.ref(:Signatures))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not found", Schema.ref(:Error))
  end

  @spec get_document_signatures(Plug.Conn.t(), map()) :: Plug.Conn.t()
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
    post("/contents/{id}/sign")
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

  @spec sign_document(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def sign_document(conn, %{"token" => token, "id" => document_id} = params) do
    current_user = conn.assigns.current_user
    ip_address = conn.remote_ip |> :inet_parse.ntoa() |> to_string()
    params = Map.merge(params, %{"ip_address" => ip_address})

    with %Instance{} = instance <- Documents.show_instance(document_id, current_user),
         %ESignature{counter_party: counter_party} <-
           Signatures.verify_signature_by_token(instance, current_user, token),
         %ESignature{} = signature <- Signatures.get_signature_by_counterparty(counter_party),
         %ESignature{} = updated_signature <-
           CounterParties.sign_document(counter_party, signature, params) do
      Signatures.check_document_signature_status(instance)
      Signatures.notify_document_owner_email(updated_signature)
      render(conn, "signature.json", signature: updated_signature)
    end
  end

  @doc """
  Validate a signature for a document
  """
  swagger_path :validate_signature do
    post("/contents/{id}/validate_signature/{token}")
    summary("Validate a document signature")
    description("API to validate a document signature")

    parameters do
      id(:path, :string, "Document ID", required: true)
      token(:path, :string, "Signature verification token", required: true)
    end

    response(200, "Ok", Schema.ref(:Signature))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not found", Schema.ref(:Error))
  end

  @spec validate_signature(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def validate_signature(conn, %{"token" => token, "id" => document_id}) do
    current_user = conn.assigns.current_user

    with %Instance{} = instance <- Documents.show_instance(document_id, current_user),
         %ESignature{} = signature <-
           Signatures.verify_signature_by_token(instance, current_user, token) do
      render(conn, "signature.json", signature: signature)
    end
  end

  @doc """
  Revoke a signature request
  """
  swagger_path :revoke_signature do
    delete("/contents/{id}/signatures/{counter_party_id}")
    summary("Revoke a signature request")
    description("API to revoke a signature request")

    parameters do
      id(:path, :string, "Document ID", required: true)
      counter_party_id(:path, :string, "Counter Party ID", required: true)
    end

    response(200, "Ok", Schema.ref(:Signature))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not found", Schema.ref(:Error))
  end

  @spec revoke_signature(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def revoke_signature(conn, %{"id" => document_id, "counter_party_id" => counter_party_id}) do
    current_user = conn.assigns.current_user

    with %Instance{} = _instance <- Documents.show_instance(document_id, current_user),
         %CounterParty{} = counter_party <-
           CounterParties.get_counterparty(document_id, counter_party_id),
         %ESignature{} = signature <- Signatures.get_signature_by_counterparty(counter_party),
         {:ok, %ESignature{} = deleted_signature} <- Signatures.delete_signature(signature) do
      render(conn, "signature.json", signature: deleted_signature)
    end
  end
end
