defmodule WraftDocWeb.Api.V1.SignatureController do
  use WraftDocWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias WraftDocWeb.Schemas

  plug WraftDocWeb.Plug.AddActionLog

  # This plug ensures the guest user has access to the document
  plug WraftDocWeb.Plug.Authorized,
    only: [:list_counterparties, :get_document_signatures, :apply_signature]

  plug WraftDocWeb.Plug.AddDocumentAuditLog
       when action in [
              :generate_signature,
              :add_counterparty,
              :request_signature,
              :apply_signature
            ]

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.Account
  alias WraftDoc.Account.User
  alias WraftDoc.AuthTokens
  alias WraftDoc.AuthTokens.AuthToken
  alias WraftDoc.Client.Minio
  alias WraftDoc.Client.Minio.DownloadError
  alias WraftDoc.Client.Minio.UploadError
  alias WraftDoc.CounterParties
  alias WraftDoc.CounterParties.CounterParty
  alias WraftDoc.Documents
  alias WraftDoc.Documents.ESignature
  alias WraftDoc.Documents.Instance
  alias WraftDoc.Documents.Signatures

  tags(["Signatures"])

  @doc """
  Request a signature for a document from a counterparty
  """
  operation(:add_counterparty,
    summary: "Request document signature from counterparty",
    description: "API to request a signature for a document from a counterparty",
    parameters: [
      id: [in: :path, type: :string, description: "Document ID", required: true]
    ],
    request_body:
      {"Signature request details", "application/json", Schemas.Signature.CounterPartyRequest},
    responses: [
      ok: {"Ok", "application/json", Schemas.Signature.SignatureResponse},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error},
      not_found: {"Not found", "application/json", Schemas.Error},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Schemas.Error}
    ]
  )

  @spec add_counterparty(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def add_counterparty(conn, %{"id" => document_id, "email" => _email} = params) do
    current_user = conn.assigns.current_user

    with %Instance{} = instance <- Documents.show_instance(document_id, current_user),
         %User{name: invited_user_name} = invited_user <-
           Account.get_or_create_guest_user(params),
         %CounterParty{} = counterparty <-
           CounterParties.add_counterparty(instance, params, invited_user) do
      conn
      |> Plug.Conn.assign(
        :audit_log_message,
        "#{current_user.name} added #{invited_user_name} as a counterparty"
      )
      |> render("counterparty.json", counterparty: counterparty)
    end
  end

  @doc """
  List counterparties for a document
  """
  operation(:list_counterparties,
    summary: "List document counterparties",
    description: "API to list all counterparties for a document",
    parameters: [
      id: [in: :path, type: :string, description: "Document ID", required: true]
    ],
    responses: [
      ok: {"Ok", "application/json", Schemas.Signature.CounterPartiesList},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error},
      not_found: {"Not found", "application/json", Schemas.Error}
    ]
  )

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
  operation(:request_signature,
    summary: "Request document signature from counterparty by email",
    description: "API to request a signature for a document from a counterparty by email",
    parameters: [
      id: [in: :path, type: :string, description: "Document ID", required: true],
      counterparty_id: [
        in: :query,
        type: :string,
        description:
          "Counter Party ID (optional). If not provided, sends to all pending counterparties."
      ]
    ],
    responses: [
      ok: {"Ok", "application/json", Schemas.Signature.SignatureResponse},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error},
      not_found: {"Not found", "application/json", Schemas.Error},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Schemas.Error}
    ]
  )

  @spec request_signature(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def request_signature(
        conn,
        %{"id" => document_id, "counterparty_id" => counter_party_id}
      ) do
    current_user = conn.assigns.current_user

    with %Instance{} = instance <- Documents.show_instance(document_id, current_user),
         %CounterParty{email: email, signature_status: :pending} = counter_party <-
           CounterParties.get_counterparty(document_id, counter_party_id),
         {:ok, %AuthToken{value: token}} <-
           AuthTokens.create_signer_invite_token(instance, email),
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
         counter_parties <- Signatures.get_document_pending_signatures(document_id) do
      Signatures.signature_request_email(instance, counter_parties, current_user)

      render(conn, "email.json",
        info: "Signature request email sent to #{length(counter_parties)} counterparties"
      )
    end
  end

  @doc """
  Get a specific signature for a document
  """
  operation(:get_signature,
    summary: "Get specific document signature",
    description: "API to get a specific signature by its ID for a document",
    parameters: [
      id: [in: :path, type: :string, description: "Document ID", required: true],
      signature_id: [in: :path, type: :string, description: "Signature ID", required: true]
    ],
    responses: [
      ok: {"Ok", "application/json", Schemas.Signature.SignatureResponse},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error},
      not_found: {"Not found", "application/json", Schemas.Error}
    ]
  )

  @spec get_signature(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def get_signature(conn, %{"id" => document_id, "signature_id" => signature_id}) do
    current_user = conn.assigns.current_user

    with %Instance{} = _instance <- Documents.show_instance(document_id, current_user),
         %ESignature{} = signature <- Signatures.get_signature(signature_id, document_id) do
      render(conn, "signature.json", signature: signature)
    end
  end

  @doc """
  Create a signature record for an existing counterparty
  """
  operation(:create_signature,
    summary: "Create signature record",
    description:
      "API to create a signature record for an existing counterparty on a document. This generates the verification token but does not send the email (use request_signature for that).",
    parameters: [
      id: [in: :path, type: :string, description: "Document ID", required: true]
    ],
    request_body:
      {"Signature creation details", "application/json", Schemas.Signature.CreateSignatureRequest},
    responses: [
      ok: {"Ok", "application/json", Schemas.Signature.SignatureResponse},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error},
      not_found: {"Not found", "application/json", Schemas.Error},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Schemas.Error}
    ]
  )

  @spec create_signature(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create_signature(conn, %{"id" => document_id}) do
    current_user = conn.assigns.current_user

    with %Instance{} = instance <- Documents.show_instance(document_id, current_user),
         %ESignature{} = signature <- Signatures.create_signature(instance, current_user) do
      render(conn, "signature.json", signature: signature)
    end
  end

  @doc """
  Get all signatures for a document
  """
  operation(:get_document_signatures,
    summary: "Get document signatures",
    description: "API to get all signatures for a document",
    parameters: [
      id: [in: :path, type: :string, description: "Document ID", required: true]
    ],
    responses: [
      ok: {"Ok", "application/json", Schemas.Signature.SignaturesList},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error},
      not_found: {"Not found", "application/json", Schemas.Error}
    ]
  )

  @spec get_document_signatures(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def get_document_signatures(conn, %{"id" => document_id}) do
    current_user = conn.assigns.current_user

    with %Instance{build: document_url} <-
           Documents.show_instance(document_id, current_user),
         {:ok, signatures} <- Signatures.get_document_signatures(document_id) do
      render(conn, "signatures.json", signatures: signatures, document_url: document_url)
    end
  end

  @doc """
  Revoke a signature request
  """
  operation(:revoke_signature,
    summary: "Revoke a signature request",
    description: "API to revoke a signature request",
    parameters: [
      id: [in: :path, type: :string, description: "Document ID", required: true],
      counter_party_id: [
        in: :path,
        type: :string,
        description: "Counter Party ID",
        required: true
      ]
    ],
    responses: [
      ok: {"Ok", "application/json", Schemas.Signature.SignatureResponse},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error},
      not_found: {"Not found", "application/json", Schemas.Error}
    ]
  )

  @spec revoke_signature(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def revoke_signature(
        conn,
        %{"id" => document_id, "counter_party_id" => counter_party_id}
      ) do
    current_user = conn.assigns.current_user

    with %Instance{} = _instance <- Documents.show_instance(document_id, current_user),
         %CounterParty{} = counter_party <-
           CounterParties.get_counterparty(document_id, counter_party_id),
         {_, nil} <- Signatures.delete_signatures(counter_party) do
      send_resp(conn, 200, Jason.encode!(%{info: "Signature request revoked"}))
    end
  end

  @doc """
  Generate a signature
  """
  operation(:generate_signature,
    summary: "Generate a signature",
    description: "API to generate a signature",
    parameters: [
      id: [in: :path, type: :string, description: "Document ID", required: true]
    ],
    request_body:
      {"Signature process details", "application/json", Schemas.Signature.SignatureProcess},
    responses: [
      ok: {"Ok", "application/json", Schemas.Signature.SignatureResponse},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error},
      not_found: {"Not found", "application/json", Schemas.Error}
    ]
  )

  @spec generate_signature(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def generate_signature(conn, %{"id" => document_id}) do
    current_user = conn.assigns.current_user

    with %Instance{build: document_url} = instance <-
           Documents.show_instance(document_id, current_user),
         {:ok, signatures} <- Signatures.generate_signature(instance, current_user) do
      render(conn, "signatures.json", signatures: signatures, document_url: document_url)
    end
  rescue
    DownloadError ->
      conn
      |> put_status(404)
      |> json(%{error: "File not found"})
  end

  @doc """
  Update a signature
  """
  operation(:update_signature,
    summary: "Update a signature",
    description: "API to update a signature's details",
    parameters: [
      id: [in: :path, type: :string, description: "Document ID", required: true],
      signature_id: [in: :path, type: :string, description: "Signature ID", required: true]
    ],
    request_body:
      {"Updated signature details", "application/json", Schemas.Signature.SignatureProcess},
    responses: [
      ok: {"Ok", "application/json", Schemas.Signature.SignatureResponse},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error},
      not_found: {"Not found", "application/json", Schemas.Error},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Schemas.Error}
    ]
  )

  @spec update_signature(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update_signature(conn, %{"id" => document_id, "signature_id" => signature_id} = params) do
    current_user = conn.assigns.current_user

    with %Instance{} = _instance <- Documents.show_instance(document_id, current_user),
         %ESignature{} = signature <- Signatures.get_signature(signature_id, document_id),
         {:ok, %ESignature{} = updated_signature} <-
           Signatures.update_e_signature(signature, params) do
      render(conn, "signature.json", signature: updated_signature)
    end
  end

  @doc """
  Assign a counter party to a signature
  """
  operation(:assign_counter_party,
    summary: "Assign counter party to signature",
    description: "API to assign a counter party to an existing signature",
    parameters: [
      id: [in: :path, type: :string, description: "Document ID", required: true],
      signature_id: [in: :path, type: :string, description: "Signature ID", required: true]
    ],
    request_body:
      {"Counter Party ID", "application/json", Schemas.Signature.AssignCounterPartyRequest},
    responses: [
      ok: {"Ok", "application/json", Schemas.Signature.SignatureResponse},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error},
      not_found: {"Not found", "application/json", Schemas.Error},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Schemas.Error}
    ]
  )

  @spec assign_counter_party(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def assign_counter_party(
        conn,
        %{
          "id" => document_id,
          "signature_id" => signature_id,
          "counterparty_id" => counter_party_id
        }
      ) do
    current_user = conn.assigns.current_user

    with %Instance{} = _instance <- Documents.show_instance(document_id, current_user),
         %ESignature{} = signature <- Signatures.get_signature(signature_id, document_id),
         %CounterParty{} = counter_party <-
           CounterParties.get_counterparty(document_id, counter_party_id),
         {:ok, %ESignature{} = updated_signature} <-
           Signatures.assign_counter_party(signature, counter_party) do
      render(conn, "signature.json", signature: updated_signature)
    end
  end

  @doc """
  Apply a visual signature to a PDF document
  """
  operation(:apply_signature,
    summary: "Apply visual signature to PDF",
    description: "API to apply a visual signature to a PDF document",
    parameters: [
      id: [in: :path, type: :string, description: "Document ID", required: true],
      signature_id: [in: :path, type: :string, description: "Signature ID", required: true]
    ],
    request_body:
      {"Signature image file", "multipart/form-data", Schemas.Signature.SignatureProcess},
    responses: [
      ok: {"Ok", "application/json", Schemas.Signature.SignedPdfResponse},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error},
      not_found: {"Not found", "application/json", Schemas.Error},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Schemas.Error}
    ]
  )

  @spec apply_signature(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def apply_signature(conn, %{"id" => document_id} = params) do
    current_user = conn.assigns.current_user
    device = conn |> get_req_header("user-agent") |> List.first()
    ip_address = conn.remote_ip |> :inet_parse.ntoa() |> to_string()
    params = Map.merge(params, %{"ip_address" => ip_address, "device" => device})

    with %Instance{} = instance <- Documents.show_instance(document_id, current_user),
         %CounterParty{} = counter_party <-
           CounterParties.get_counterparty_with_signatures(current_user, document_id),
         signature_status <- Signatures.document_signed?(instance),
         {:ok, signed_pdf_path} <-
           Signatures.apply_visual_signature_to_document(
             counter_party,
             instance,
             params,
             signature_status
           ),
         {:ok, %CounterParty{} = _counter_party} <-
           CounterParties.counter_party_sign(counter_party, params),
         {:ok, _} <-
           Signatures.apply_digital_signature_to_document(
             instance,
             signature_status,
             current_user
           ) do
      render(conn, "signed_pdf.json",
        url: Minio.generate_url(signed_pdf_path),
        sign_status: signature_status
      )
    end
  rescue
    UploadError ->
      conn
      |> put_status(404)
      |> json(%{error: "File not found"})
  end
end
