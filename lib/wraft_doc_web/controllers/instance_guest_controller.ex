defmodule WraftDocWeb.Api.V1.InstanceGuestController do
  use WraftDocWeb, :controller
  use OpenApiSpex.ControllerSpecs

  plug WraftDocWeb.Plug.AddActionLog

  plug WraftDocWeb.Plug.AddDocumentAuditLog
       when action in [:invite]

  action_fallback(WraftDocWeb.FallbackController)

  require Logger

  alias WraftDoc.Account
  alias WraftDoc.Account.User
  alias WraftDoc.AuthTokens
  alias WraftDoc.AuthTokens.AuthToken
  alias WraftDoc.CounterParties
  alias WraftDoc.CounterParties.CounterParty
  alias WraftDoc.Documents
  alias WraftDoc.Documents.ContentCollaboration
  alias WraftDoc.Documents.Instance
  alias WraftDocWeb.Schemas.Content, as: ContentSchema
  alias WraftDocWeb.Schemas.Error
  alias WraftDocWeb.Schemas.InstanceGuest, as: InstanceGuestSchema

  tags(["InstanceGuests"])

  operation(:invite,
    summary: "Share an instance",
    description: "Api to share an instance",
    parameters: [
      id: [in: :path, type: :string, description: "Instance id", required: true]
    ],
    request_body:
      {"Share Request", "application/json", InstanceGuestSchema.InviteDocumentRequest},
    responses: [
      ok: {"Ok", "application/json", InstanceGuestSchema.Collaborator},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  @spec invite(Plug.Conn.t(), map) :: Plug.Conn.t()
  def invite(conn, %{"id" => document_id, "email" => _email} = params) do
    current_user = conn.assigns.current_user

    with %Instance{state_id: state_id} = instance <-
           Documents.show_instance(document_id, current_user),
         %User{name: invited_user_name} = invited_user <-
           Account.get_or_create_guest_user(params),
         %ContentCollaboration{} = collaborator <-
           Documents.add_content_collaborator(current_user, instance, invited_user, params),
         {:ok, %AuthToken{value: token}} <-
           AuthTokens.create_document_invite_token(state_id, params),
         {:ok, %Oban.Job{}} <- Documents.send_email(instance, invited_user, token) do
      conn
      |> Plug.Conn.assign(
        :audit_log_message,
        "#{current_user.name} invited #{invited_user_name}"
      )
      |> render("collaborator.json", collaborator: collaborator)
    end
  end

  operation(:verify_document_access,
    summary: "Verify document invite token",
    description: "Api to verify document invite token",
    parameters: [
      id: [in: :path, type: :string, description: "Instance id", required: true],
      token: [in: :path, type: :string, description: "Invite token", required: true]
    ],
    responses: [
      ok: {"Ok", "application/json", InstanceGuestSchema.VerifyDocumentInviteTokenResponse},
      unauthorized: {"Unauthorized", "application/json", Error},
      not_found: {"Not found", "application/json", Error}
    ]
  )

  @spec verify_document_access(Plug.Conn.t(), map) :: Plug.Conn.t()
  def verify_document_access(conn, %{
        "token" => invite_token,
        "id" => document_id,
        "type" => "sign"
      }) do
    with {:ok, %{email: email, document_id: ^document_id}} <-
           AuthTokens.check_token(invite_token, :signer_invite),
         %User{} = invited_signatory <- Account.get_user_by_email(email),
         %CounterParty{} = counter_party <- CounterParties.get_counterparty(document_id, email),
         %CounterParty{} = counter_party <- CounterParties.approve_document_access(counter_party),
         {:ok, guest_access_token, _} <-
           AuthTokens.create_guest_access_token(invited_signatory, %{
             email: email,
             document_id: document_id,
             type: "sign"
           }) do
      render(conn, "verify_signer.json",
        counter_party: counter_party,
        user: invited_signatory,
        token: guest_access_token,
        role: "sign"
      )
    else
      _ ->
        conn
        |> put_resp_header("content-type", "application/json")
        |> send_resp(
          401,
          Jason.encode!(%{errors: "Document id does not match the invite token."})
        )
    end
  end

  def verify_document_access(conn, %{"token" => invite_token, "id" => document_id}) do
    with {:ok, %{email: email, document_id: ^document_id, state_id: state_id, role: role}} <-
           AuthTokens.check_token(invite_token, :document_invite),
         %User{} = invited_user <- Account.get_user_by_email(email),
         %ContentCollaboration{} = content_collaboration <-
           Documents.get_content_collaboration(document_id, invited_user, state_id),
         {:ok, %ContentCollaboration{}} <-
           Documents.accept_document_access(content_collaboration),
         {:ok, guest_access_token, _} <-
           AuthTokens.create_guest_access_token(invited_user, %{
             email: email,
             role: role,
             document_id: document_id,
             state_id: state_id,
             type: "guest"
           }) do
      render(conn, "verify_collaborator.json",
        user: invited_user,
        token: guest_access_token,
        role: role
      )
    else
      _ ->
        conn
        |> put_resp_header("content-type", "application/json")
        |> send_resp(
          401,
          Jason.encode!(%{errors: "Document id does not match the invite token."})
        )
    end
  end

  operation(:revoke_document_access,
    summary: "Revoke document access",
    description: "Api to revoke document access",
    parameters: [
      id: [in: :path, type: :string, description: "Instance id", required: true],
      collaborator_id: [in: :path, type: :string, description: "Collaborator id", required: true]
    ],
    responses: [
      ok: {"Ok", "application/json", InstanceGuestSchema.Collaborator},
      unauthorized: {"Unauthorized", "application/json", Error},
      not_found: {"Not found", "application/json", Error},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error}
    ]
  )

  @spec revoke_document_access(Plug.Conn.t(), map) :: Plug.Conn.t()
  def revoke_document_access(
        conn,
        %{"id" => document_id, "collaborator_id" => collaborator_id}
      ) do
    current_user = conn.assigns.current_user

    with %Instance{} = _instance <- Documents.show_instance(document_id, current_user),
         %ContentCollaboration{} = collaborator <-
           Documents.get_content_collaboration(collaborator_id),
         %ContentCollaboration{} = collaborator <-
           Documents.revoke_document_access(current_user, collaborator) do
      render(conn, "collaborator.json", collaborator: collaborator)
    end
  end

  operation(:list_collaborators,
    summary: "List document instance collaborators",
    description: "Api to list document instance collaborators",
    parameters: [
      id: [in: :path, type: :string, description: "Instance id", required: true]
    ],
    responses: [
      ok: {"Ok", "application/json", InstanceGuestSchema.Collaborator},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  @spec list_collaborators(Plug.Conn.t(), map) :: Plug.Conn.t()
  def list_collaborators(conn, %{"id" => document_id}) do
    current_user = conn.assigns.current_user

    with %Instance{} = instance <- Documents.show_instance(document_id, current_user),
         collaborators when is_list(collaborators) <- Documents.list_collaborators(instance) do
      render(conn, "collaborators.json", collaborators: collaborators)
    end
  end

  operation(:update_collaborator_role,
    summary: "Update Collaborator role",
    description: "Api to update collaborator role",
    parameters: [
      id: [in: :path, type: :string, description: "Instance id", required: true],
      collaborator_id: [in: :path, type: :string, description: "Collaborator id", required: true]
    ],
    responses: [
      ok: {"Ok", "application/json", ContentSchema.Content},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  @spec update_collaborator_role(Plug.Conn.t(), map) :: Plug.Conn.t()
  def update_collaborator_role(
        conn,
        %{
          "id" => document_id,
          "collaborator_id" => collaborator_id
        } = params
      ) do
    current_user = conn.assigns.current_user

    with %Instance{} = _instance <- Documents.show_instance(document_id, current_user),
         %ContentCollaboration{} = collaborator <-
           Documents.get_content_collaboration(collaborator_id),
         %ContentCollaboration{} = collaborator <-
           Documents.update_collaborator_role(collaborator, params) do
      render(conn, "collaborator.json", collaborator: collaborator)
    end
  end

  operation(:remove_counterparty,
    summary: "Remove counterparty from a document",
    description: "Api to remove counterparty from a document",
    parameters: [
      id: [in: :path, type: :string, description: "Instance id", required: true],
      counterparty_id: [in: :path, type: :string, description: "Counterparty id", required: true]
    ],
    responses: [
      ok: {"Ok", "application/json", InstanceGuestSchema.CounterPartiesResponse},
      unauthorized: {"Unauthorized", "application/json", Error},
      not_found: {"Not found", "application/json", Error},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error}
    ]
  )

  @spec remove_counterparty(Plug.Conn.t(), map) :: Plug.Conn.t()
  def remove_counterparty(
        conn,
        %{"id" => document_id, "counterparty_id" => counterparty_id}
      ) do
    current_user = conn.assigns.current_user

    with %Instance{} = _instance <- Documents.show_instance(document_id, current_user),
         %CounterParty{} = counterparty <-
           CounterParties.get_counterparty(document_id, counterparty_id),
         %CounterParty{} = counterparty <- CounterParties.remove_counterparty(counterparty) do
      render(conn, "counterparty.json", counterparty: counterparty)
    end
  end
end
