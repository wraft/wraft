defmodule WraftDocWeb.Api.V1.InstanceGuestController do
  use WraftDocWeb, :controller
  use PhoenixSwagger

  plug WraftDocWeb.Plug.AddActionLog

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

  def swagger_definitions do
    %{
      InviteDocumentRequest:
        swagger_schema do
          title("Share document request")
          description("Request to share a document")

          properties do
            email(:string, "Email", required: true)
            role(:string, "Role", required: true, enum: ["suggestor", "viewer"])
          end

          example(%{
            "email" => "example@example.com",
            "role" => "suggestor"
          })
        end,
      VerifyDocumentInviteTokenResponse:
        swagger_schema do
          title("Verify document invite token response")
          description("Response for document invite token verification")

          properties do
            token(:string, "Token")
            role(:string, "Role")
            user(Schema.ref(:User), "User")
          end

          example(%{
            token: "1232148nb3478",
            role: "suggestor",
            user: %{
              id: "6529b52b-071c-4b82-950c-539b73b8833e",
              name: "John Doe",
              email: "john@example.com",
              is_guest: false,
              email_verified: true,
              inserted_at: "2023-04-23T10:00:00Z",
              updated_at: "2023-04-23T10:00:00Z"
            }
          })
        end,
      Collaborator:
        swagger_schema do
          title("Collaborator")
          description("A collaborator")

          properties do
            id(:string, "Id")
            name(:string, "Name")
            email(:string, "Email")
            role(:string, "Role")
            status(:string, "Status")
            created_at(:string, "Created at")
            updated_at(:string, "Updated at")
          end

          example(%{
            id: "6529b52b-071c-4b82-950c-539b73b8833e",
            name: "John Doe",
            email: "john@example.com",
            role: "viewer",
            status: "active",
            created_at: "2023-04-23T10:00:00Z",
            updated_at: "2023-04-23T10:00:00Z"
          })
        end,
      CounterPartiesRequest:
        swagger_schema do
          title("Counter parties request")
          description("Request to create counter parties")

          properties do
            name(:string, "Name", required: true)
            guest_user_id(:string, "Guest user id", required: true)
          end

          example(%{
            name: "John Doe",
            guest_user_id: "1232148nb3478"
          })
        end,
      CounterPartiesResponse:
        swagger_schema do
          title("Counter parties response")
          description("Response for counter parties")

          properties do
            id(:string, "Id")
            name(:string, "Name")
            guest_user_id(:string, "Guest user id")
            content(Schema.ref(:Content))
            created_at(:string, "Created at")
            updated_at(:string, "Updated at")
          end

          example(%{
            id: "6529b52b-071c-4b82-950c-539b73b8833e",
            name: "John Doe",
            guest_user_id: "1232148nb3478",
            content: %{
              id: "1232148nb3478",
              instance_id: "OFFL01",
              raw: "Content",
              serialized: %{title: "Title of the content", body: "Body of the content"},
              updated_at: "2020-01-21T14:00:00Z",
              inserted_at: "2020-02-21T14:00:00Z"
            },
            created_at: "2023-04-23T10:00:00Z",
            updated_at: "2023-04-23T10:00:00Z"
          })
        end,
      ShareDocumentRequest:
        swagger_schema do
          title("Share document request")
          description("Request to share a document")

          properties do
            email(:string, "Email", required: true)
            role(:string, "Role", required: true, enum: ["suggestor", "viewer"])
            state_id(:string, "Document State", required: true)
          end

          example(%{
            "email" => "example@example.com",
            "role" => "suggestor",
            "state_id" => "a102cdb1-e5f4-4c28-98ec-9a10a94b9173"
          })
        end
    }
  end

  @doc """
   Share an instance.
  """
  swagger_path :invite do
    post("/contents/{id}/invite")
    summary("Share an instance")
    description("Api to share an instance")

    parameters do
      id(:path, :string, "Instance id", required: true)
      content(:body, Schema.ref(:InviteDocumentRequest), "Share Request", required: true)
    end

    response(200, "Ok", Schema.ref(:Collaborator))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec invite(Plug.Conn.t(), map) :: Plug.Conn.t()
  def invite(conn, %{"id" => document_id, "email" => _email} = params) do
    current_user = conn.assigns.current_user

    with %Instance{state_id: state_id} = instance <-
           Documents.show_instance(document_id, current_user, params),
         %User{} = invited_user <- Account.get_or_create_guest_user(params),
         %ContentCollaboration{} = collaborator <-
           Documents.add_content_collaborator(current_user, instance, invited_user, params),
         {:ok, %AuthToken{value: token}} <-
           AuthTokens.create_document_invite_token(state_id, params),
         {:ok, %Oban.Job{}} <- Documents.send_email(instance, invited_user, token) do
      render(conn, "collaborator.json", collaborator: collaborator)
    end
  end

  @doc """
  Verify document invite token.
  """
  swagger_path :verify_document_access do
    get("/contents/{id}/verify_access/{token}")
    summary("Verify document invite token")
    description("Api to verify document invite token")

    parameters do
      id(:path, :string, "Instance id", required: true)
      token(:path, :string, "Invite token", required: true)
    end

    response(200, "Ok", Schema.ref(:VerifyDocumentInviteTokenResponse))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not found", Schema.ref(:Error))
  end

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

  @doc """
  Revoke document access.
  """
  swagger_path :revoke_document_access do
    put("/contents/{id}/revoke_access/{collaborator_id}")
    summary("Revoke document access")
    description("Api to revoke document access")

    parameters do
      id(:path, :string, "Instance id", required: true)
      collaborator_id(:path, :string, "Collaborator id", required: true)
    end

    response(200, "Ok", Schema.ref(:Collaborator))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not found", Schema.ref(:Error))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
  end

  @spec revoke_document_access(Plug.Conn.t(), map) :: Plug.Conn.t()
  def revoke_document_access(
        conn,
        %{"id" => document_id, "collaborator_id" => collaborator_id} = params
      ) do
    current_user = conn.assigns.current_user

    with %Instance{} = _instance <- Documents.show_instance(document_id, current_user, params),
         %ContentCollaboration{} = collaborator <-
           Documents.get_content_collaboration(collaborator_id),
         %ContentCollaboration{} = collaborator <-
           Documents.revoke_document_access(current_user, collaborator) do
      render(conn, "collaborator.json", collaborator: collaborator)
    end
  end

  @doc """
  List document instance collaborators.
  """
  swagger_path :collaborators do
    get("/contents/{id}/collaborators")
    summary("List document instance collaborators")
    description("Api to list document instance collaborators")

    parameters do
      id(:path, :string, "Instance id", required: true)
    end

    response(200, "Ok", Schema.ref(:Collaborator))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec list_collaborators(Plug.Conn.t(), map) :: Plug.Conn.t()
  def list_collaborators(conn, %{"id" => document_id} = params) do
    current_user = conn.assigns.current_user

    with %Instance{} = instance <- Documents.show_instance(document_id, current_user, params),
         collaborators when is_list(collaborators) <- Documents.list_collaborators(instance) do
      render(conn, "collaborators.json", collaborators: collaborators)
    end
  end

  @doc """
  Update Collaborator role.
  """
  swagger_path :update_collaborator_role do
    patch("/contents/{id}/collaborators/{collaborator_id}")
    summary("Update Collaborator role")
    description("Api to update collaborator role")

    parameters do
      id(:path, :string, "Instance id", required: true)
      collaborator_id(:path, :string, "Collaborator id", required: true)
    end

    response(200, "Ok", Schema.ref(:Content))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec update_collaborator_role(Plug.Conn.t(), map) :: Plug.Conn.t()
  def update_collaborator_role(
        conn,
        %{
          "id" => document_id,
          "collaborator_id" => collaborator_id
        } = params
      ) do
    current_user = conn.assigns.current_user

    with %Instance{} = _instance <- Documents.show_instance(document_id, current_user, params),
         %ContentCollaboration{} = collaborator <-
           Documents.get_content_collaboration(collaborator_id),
         %ContentCollaboration{} = collaborator <-
           Documents.update_collaborator_role(collaborator, params) do
      render(conn, "collaborator.json", collaborator: collaborator)
    end
  end

  @doc """
  Remove counterparty from a contract document
  """
  swagger_path :remove_counterparty do
    PhoenixSwagger.Path.delete("/contents/{id}/remove_counterparty/{counterparty_id}")
    summary("Remove counterparty from a document")
    description("Api to remove counterparty from a document")

    parameters do
      id(:path, :string, "Instance id", required: true)
      counterparty_id(:path, :string, "Counterparty id", required: true)
    end

    response(200, "Ok", Schema.ref(:CounterPartyResponse))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not found", Schema.ref(:Error))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
  end

  @spec remove_counterparty(Plug.Conn.t(), map) :: Plug.Conn.t()
  def remove_counterparty(
        conn,
        %{"id" => document_id, "counterparty_id" => counterparty_id} = params
      ) do
    current_user = conn.assigns.current_user

    with %Instance{} = _instance <- Documents.show_instance(document_id, current_user, params),
         %CounterParty{} = counterparty <-
           CounterParties.get_counterparty(document_id, counterparty_id),
         %CounterParty{} = counterparty <- CounterParties.remove_counterparty(counterparty) do
      render(conn, "counterparty.json", counterparty: counterparty)
    end
  end
end
