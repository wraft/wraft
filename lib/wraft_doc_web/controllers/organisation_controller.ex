defmodule WraftDocWeb.Api.V1.OrganisationController do
  use WraftDocWeb, :controller
  use OpenApiSpex.ControllerSpecs

  plug WraftDocWeb.Plug.AddActionLog

  plug WraftDocWeb.Plug.Authorized,
    update: "workspace:update",
    delete: "workspace:delete",
    invite: "members:manage",
    members: "members:show",
    remove_user: "members:manage"

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.Account
  alias WraftDoc.Account.User
  alias WraftDoc.Account.UserOrganisation
  alias WraftDoc.AuthTokens
  alias WraftDoc.AuthTokens.AuthToken
  alias WraftDoc.Enterprise
  alias WraftDoc.Enterprise.Organisation
  alias WraftDoc.InvitedUsers
  alias WraftDoc.InvitedUsers.InvitedUser
  alias WraftDocWeb.Guardian
  alias WraftDocWeb.Schemas

  tags(["Organisation"])

  @doc """
  New registration
  """
  operation(:create,
    summary: "Register organisation",
    description: "Create Organisation API",
    request_body:
      {"Organisation data", "multipart/form-data",
       %OpenApiSpex.Schema{
         type: :object,
         properties: %{
           name: %OpenApiSpex.Schema{type: :string},
           legal_name: %OpenApiSpex.Schema{type: :string},
           address: %OpenApiSpex.Schema{type: :string},
           name_of_ceo: %OpenApiSpex.Schema{type: :string},
           name_of_cto: %OpenApiSpex.Schema{type: :string},
           gstin: %OpenApiSpex.Schema{type: :string},
           corporate_id: %OpenApiSpex.Schema{type: :string},
           email: %OpenApiSpex.Schema{type: :string},
           logo: %OpenApiSpex.Schema{type: :string, format: :binary},
           phone: %OpenApiSpex.Schema{type: :string},
           url: %OpenApiSpex.Schema{type: :string}
         }
       }},
    responses: [
      created: {"Created", "application/json", Schemas.Organisation.Organisation},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Schemas.Error},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error}
    ]
  )

  @doc """
  Creates a new organisation
  """
  @spec create(Plug.Conn.t(), map) :: Plug.Conn.t()
  def create(conn, params) do
    current_user = conn.assigns.current_user

    case FunWithFlags.enabled?(:waiting_list_organisation_create_control,
           for: %{email: current_user.email}
         ) do
      true ->
        with %Organisation{id: organisation_id} = organisation <-
               Enterprise.create_organisation(current_user, params),
             :ok <- Enterprise.insert_organisation_roles(organisation_id, current_user.id),
             {:ok, %Oban.Job{}} <-
               Enterprise.create_default_worker_job(
                 %{
                   organisation_id: organisation_id,
                   current_user_id: current_user.id
                 },
                 "wraft_templates"
               ) do
          render(conn, "create.json", organisation: organisation)
        end

      false ->
        conn
        |> put_resp_header("content-type", "application/json")
        |> send_resp(
          401,
          Jason.encode!("User does not have privilege to create an organisation!")
        )
    end
  end

  @doc """
  Update an organisation
  """
  operation(:update,
    summary: "Update an organisation",
    description: "API to update an organisation",
    parameters: [
      id: [in: :path, type: :string, description: "organisation id", required: true]
    ],
    request_body:
      {"Organisation data", "multipart/form-data",
       %OpenApiSpex.Schema{
         type: :object,
         properties: %{
           name: %OpenApiSpex.Schema{type: :string},
           legal_name: %OpenApiSpex.Schema{type: :string},
           address: %OpenApiSpex.Schema{type: :string},
           name_of_ceo: %OpenApiSpex.Schema{type: :string},
           name_of_cto: %OpenApiSpex.Schema{type: :string},
           gstin: %OpenApiSpex.Schema{type: :string},
           corporate_id: %OpenApiSpex.Schema{type: :string},
           email: %OpenApiSpex.Schema{type: :string},
           logo: %OpenApiSpex.Schema{type: :string, format: :binary},
           phone: %OpenApiSpex.Schema{type: :string},
           url: %OpenApiSpex.Schema{type: :string}
         }
       }},
    responses: [
      created: {"Accepted", "application/json", Schemas.Organisation.Organisation},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Schemas.Error},
      not_found: {"Not Found", "application/json", Schemas.Error},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error}
    ]
  )

  @spec update(Plug.Conn.t(), map) :: Plug.Conn.t()
  def update(conn, params) do
    %User{current_org_id: organisation_id} = conn.assigns.current_user

    with %Organisation{} = organisation <- Enterprise.get_organisation(organisation_id),
         params <- remove_name_from_params(organisation, params),
         {:ok, organisation} <-
           Enterprise.update_organisation(organisation, params) do
      render(conn, "create.json", organisation: organisation)
    end
  end

  @doc """
  Get an organisation by id
  """
  operation(:show,
    summary: "Show an Organisation",
    description: "API to show details of an organisation",
    parameters: [
      id: [in: :path, type: :string, description: "Organisation id", required: true]
    ],
    responses: [
      ok: {"Ok", "application/json", Schemas.Organisation.Organisation},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error},
      not_found: {"Not Found", "application/json", Schemas.Error}
    ]
  )

  @spec show(Plug.Conn.t(), map) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    case Enterprise.get_organisation_with_member_count(id) do
      %Organisation{} = organisation -> render(conn, "show.json", organisation: organisation)
      # TODO - Change this to use with statement and make sure it returns only 200, 404, and 401
      _ -> {:error, :invalid_id}
    end
  end

  @doc """
  Delete an organisation
  """
  operation(:delete,
    summary: "Delete an organisation",
    description: "Delete Organisation API",
    request_body:
      {"Deletion Confirmation code", "application/json",
       Schemas.Organisation.DeleteOrganisationRequest},
    responses: [
      ok: {"Ok", "application/json", Schemas.Organisation.Organisation},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Schemas.Error},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error},
      not_found: {"Not Found", "application/json", Schemas.Error}
    ]
  )

  @spec delete(Plug.Conn.t(), map) :: Plug.Conn.t()
  def delete(conn, params) do
    %{current_org_id: organisation_id, email: email} = current_user = conn.assigns.current_user

    with {:error, :already_member} <-
           Enterprise.already_member(organisation_id, email),
         %AuthToken{} = _token <- AuthTokens.verify_delete_token(current_user, params),
         %Organisation{} = organisation <- Enterprise.get_organisation(organisation_id),
         {:ok, %Organisation{}} <- Enterprise.delete_organisation(organisation),
         %{organisation: personal_org, user: user} <-
           Enterprise.get_personal_organisation_and_role(current_user),
         [access_token: access_token, refresh_token: refresh_token] <-
           Guardian.generate_tokens(user, personal_org.id) do
      Account.update_last_signed_in_org(user, personal_org.id)

      render(conn, "delete.json",
        organisation: organisation,
        access_token: access_token,
        refresh_token: refresh_token,
        user: user
      )
    else
      :ok ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(401, Jason.encode!(%{errors: "User is not a member of this organisation!"}))

      error ->
        error
    end
  end

  @doc """
    Confirmation code to delete an organisation
  """
  operation(:request_deletion,
    summary: "Organisation Deletion Code",
    description: "Request Organisation Deletion Code",
    responses: [
      ok: {"Ok", "application/json", Schemas.Organisation.DeletionRequestResponse},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Schemas.Error},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error},
      not_found: {"Not Found", "application/json", Schemas.Error}
    ]
  )

  @spec request_deletion(Plug.Conn.t(), map) :: Plug.Conn.t()
  def request_deletion(conn, _params) do
    %{current_org_id: organisation_id, email: email, id: user_id} =
      current_user = conn.assigns.current_user

    with {:error, :already_member} <- Enterprise.already_member(organisation_id, email),
         %Organisation{name: name, owner_id: owner_id} = organisation
         when name != "Personal" and owner_id == user_id <-
           Enterprise.get_organisation(organisation_id),
         {:ok, %Oban.Job{}} <-
           AuthTokens.generate_delete_token_and_send_email(current_user, organisation) do
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(200, Jason.encode!(%{info: "Delete token email sent!"}))
    else
      %Organisation{name: "Personal"} ->
        body = Jason.encode!(%{errors: "Can't delete personal organisation"})
        conn |> put_resp_content_type("application/json") |> send_resp(422, body)

      %Organisation{} ->
        body = Jason.encode!(%{errors: "Only organisation owner can request deletion"})
        conn |> put_resp_content_type("application/json") |> send_resp(403, body)

      :ok ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(401, Jason.encode!(%{errors: "User is not a member of this organisation!"}))

      error ->
        error
    end
  end

  @doc """
  Invite new member.
  """
  operation(:invite,
    summary: "Invite new member to the organisation",
    description: "Invite new member to the organisation",
    request_body: {"Invite request", "application/json", Schemas.Organisation.InviteRequest},
    responses: [
      ok: {"Ok", "application/json", Schemas.Organisation.InvitedResponse},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Schemas.Error},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error},
      not_found: {"Not Found", "application/json", Schemas.Error}
    ]
  )

  def invite(conn, params) do
    current_user = conn.assigns[:current_user]

    with %Organisation{name: name} = organisation when name != "Personal" <-
           Enterprise.get_organisation(current_user.current_org_id),
         :ok <- Enterprise.already_member(current_user.current_org_id, params["email"]),
         [_ | _] = roles <-
           (params["role_ids"] || [])
           |> Stream.map(&Account.get_role(current_user, &1))
           |> Stream.reject(&is_nil/1)
           |> Enum.map(& &1.id),
         {:ok, _} <-
           Enterprise.invite_team_member(current_user, organisation, params["email"], roles) do
      FunWithFlags.enable(:waiting_list_registration_control,
        for_actor: %{email: params["email"]}
      )

      InvitedUsers.create_or_update_invited_user(
        params["email"],
        organisation.id,
        "invited",
        roles
      )

      render(conn, "invite.json")
    else
      %Organisation{name: "Personal"} ->
        body = Jason.encode!(%{errors: "Can't invite to personal organisation"})
        conn |> put_resp_content_type("application/json") |> send_resp(422, body)

      [] ->
        body = Jason.encode!(%{errors: "No roles found"})
        conn |> put_resp_content_type("application/json") |> send_resp(404, body)

      error ->
        error
    end
  end

  @doc """
  Resends organisation invite.
  """

  operation(:resend_invite,
    summary: "Resend organisation invite",
    description: "Resends an organisation invite email to a previously invited user",
    parameters: [
      id: [
        in: :path,
        type: :string,
        description: "Invited User ID",
        required: true,
        example: "d19e10fc-4b36-46ab-a9cb-7fa52d7a289e"
      ]
    ],
    responses: [
      ok: {"Invite resent", "application/json", Schemas.Organisation.InvitedResponse},
      not_found: {"Invited user not found", "application/json", Schemas.Error}
    ]
  )

  def resend_invite(conn, %{"id" => invited_user_id} = _params) do
    current_user = conn.assigns[:current_user]

    with %Organisation{} = organisation <-
           Enterprise.get_organisation(current_user.current_org_id),
         %InvitedUser{} = invited_user <- InvitedUsers.get_invited_user_by_id(invited_user_id),
         {:ok, _} <- Enterprise.resend_invite(current_user, invited_user, organisation) do
      render(conn, "invite.json")
    end
  end

  @doc """
  Revoke organisation invite.
  """

  operation(:revoke_invite,
    summary: "Revoke organisation invite",
    description: "Revokes a previously sent organisation invite",
    parameters: [
      id: [
        in: :path,
        type: :string,
        description: "Invited User ID",
        required: true,
        example: "d19e10fc-4b36-46ab-a9cb-7fa52d7a289e"
      ]
    ],
    responses: [
      ok: {"Revoked successfully.!", "application/json", Schemas.Organisation.RevokedResponse},
      not_found: {"Invited user not found", "application/json", Schemas.Error}
    ]
  )

  def revoke_invite(conn, %{"id" => invited_user_id} = _params) do
    with %InvitedUser{} = invited_user <- InvitedUsers.get_invited_user_by_id(invited_user_id),
         {:ok, _} <- Enterprise.revoke_invite(invited_user) do
      render(conn, "revoke.json")
    end
  end

  @doc """
  List all members of a organisation
  """

  operation(:members,
    summary: "Members of an organisation",
    description: "All members of an organisation",
    parameters: [
      id: [in: :path, type: :string, description: "ID of the organisation"],
      page: [in: :query, type: :string, description: "Page number"],
      name: [in: :query, type: :string, description: "Name of the user"],
      role: [in: :query, type: :string, description: "Name of the role"],
      sort: [
        in: :query,
        type: :string,
        description: "Sort Keys => name, name_desc, joined_at, joined_at_desc"
      ]
    ],
    responses: [
      ok: {"Ok", "application/json", Schemas.Organisation.MembersIndex},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Schemas.Error},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error},
      not_found: {"Not Found", "application/json", Schemas.Error}
    ]
  )

  def members(conn, params) do
    current_user = conn.assigns[:current_user]

    with %{
           entries: members,
           page_number: page_number,
           total_pages: total_pages,
           total_entries: total_entries
         } <- Enterprise.members_index(current_user, params) do
      render(conn, "members.json",
        members: members,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      )
    end
  end

  operation(:index,
    summary: "List of all organisations",
    description: "All organisation that we have",
    parameters: [
      name: [in: :query, type: :string, description: "Organisations name"],
      page: [in: :query, type: :string, description: "Page number"]
    ],
    responses: [
      ok: {"Ok", "application/json", Schemas.Organisation.Index},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Schemas.Error},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error},
      not_found: {"Not Found", "application/json", Schemas.Error}
    ]
  )

  def index(conn, params) do
    with %{
           entries: organisations,
           page_number: page_number,
           total_pages: total_pages,
           total_entries: total_entries
         } <- Enterprise.list_organisations(params) do
      render(conn, "index.json",
        organisations: organisations,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      )
    end
  end

  operation(:remove_user,
    summary: "Api to remove a user from the given organisation",
    description: "Api to remove a user from an organisation",
    parameters: [
      id: [in: :path, type: :string, description: "User id"]
    ],
    responses: [
      ok: {"ok", "application/json", Schemas.Organisation.RemoveUser},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Schemas.Error},
      not_found: {"Not Found", "application/json", Schemas.Error},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error}
    ]
  )

  @doc """
    Remove a user from the organisation
  """
  @spec remove_user(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def remove_user(conn, %{"id" => user_id}) do
    current_user = conn.assigns[:current_user]

    with %UserOrganisation{organisation: %Organisation{owner_id: owner_id} = _organisation} =
           user_organisation <-
           Enterprise.get_user_organisation(current_user, user_id),
         {:ok, %UserOrganisation{}} <- Enterprise.remove_user(user_organisation, owner_id) do
      render(conn, "remove_user.json")
    else
      {:error, "Owner cannot be removed"} ->
        conn
        |> put_status(:forbidden_request)
        |> json(%{error: "Owner of the organisation cannot be removed"})

      error ->
        error
    end
  end

  operation(:transfer_ownership,
    summary: "Transfer organisation ownership",
    description: "Transfers organisation ownership to a specified user",
    parameters: [
      id: [in: :path, type: :string, description: "New owner's user ID", required: true]
    ],
    responses: [
      ok: {"Success", "application/json", Schemas.Organisation.Organisation},
      not_found: {"User or Organisation Not Found", "application/json", Schemas.Error},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error}
    ]
  )

  @doc """
    Transfer Organisation into a new user
  """
  @spec transfer_ownership(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def transfer_ownership(conn, %{"id" => new_user_id}) do
    %{id: user_id, current_org_id: current_org_id} = conn.assigns[:current_user]

    with %Organisation{owner_id: ^user_id} = organisation <-
           Enterprise.get_organisation(current_org_id),
         %User{email: email} <- Account.get_user(new_user_id),
         {:error, :already_member} <-
           Enterprise.already_member(current_org_id, email),
         {:ok, %Organisation{}} <-
           Enterprise.transfer_ownership(organisation, new_user_id) do
      render(conn, "transfer_ownership.json")
    else
      %Organisation{} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Only organisation owner can transfer ownership"})

      error ->
        error
    end
  end

  operation(:verify_invite_token,
    summary: "Verify invite token",
    description: "Api to verify organisation invite token",
    parameters: [
      token: [in: :path, type: :string, description: "Invite token"]
    ],
    responses: [
      ok: {"Ok", "application/json", Schemas.Organisation.VerifyOrganisationInviteTokenResponse},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error},
      not_found: {"Not Found", "application/json", Schemas.Error}
    ]
  )

  @doc """
    Verify organisation invite token
  """
  @spec verify_invite_token(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def verify_invite_token(conn, %{"token" => token}) do
    with {:ok, %{organisation_id: organisation_id, email: email}} <-
           AuthTokens.check_token(token, :invite),
         %Organisation{} = organisation <- Enterprise.get_organisation(organisation_id) do
      is_organisation_member = Enterprise.already_member(organisation_id, email)
      is_wraft_member = Account.get_user_by_email(email)

      render(conn, "verify_invite_token.json",
        organisation: organisation,
        email: email,
        is_organisation_member: is_organisation_member,
        is_wraft_member: is_wraft_member
      )
    end
  end

  operation(:invite_token_status,
    summary: "Invite token status",
    description: "API to get invite token status",
    parameters: [
      token: [in: :path, type: :string, description: "Invite token"]
    ],
    responses: [
      ok: {"Ok", "application/json", Schemas.Organisation.InviteTokenStatusResponse},
      not_found: {"Not Found", "application/json", Schemas.Error}
    ]
  )

  @doc """
    organisation invite token user status.
  """
  # TODO - Write Tests
  @spec invite_token_status(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def invite_token_status(conn, %{"token" => token}) do
    case AuthTokens.check_token(token, :invite) do
      {:ok, %{organisation_id: _organisation_id, email: email}} ->
        case Account.find(email) do
          %User{} = _user ->
            render(conn, "invite_token_status.json", isNewUser: true, email: email)

          _ ->
            render(conn, "invite_token_status.json", isNewUser: false, email: email)
        end

      _ ->
        conn
        |> put_resp_header("content-type", "application/json")
        |> send_resp(404, Jason.encode!(%{errors: "Invalid token!"}))
    end
  end

  @doc """
    Get the permissions list of the user in current organisation
  """
  operation(:permissions,
    summary: "user's permissions list",
    description: "Api to get the permissions list of the user in current organisation",
    responses: [
      ok: {"Ok", "application/json", Schemas.Organisation.PermissionsResponse},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error}
    ]
  )

  # TODO Write tests
  @spec permissions(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def permissions(conn, _params) do
    current_user = conn.assigns[:current_user]
    permissions = Enterprise.get_permissions(current_user)
    render(conn, "permissions.json", permissions: permissions)
  end

  @doc """
  Returns a list of users invited by the current user.
  """

  operation(:list_invited,
    summary: "List Invited Users",
    description: "Returns a list of users invited by the current user.",
    responses: [
      ok: {"OK", "application/json", Schemas.Organisation.InvitedUsersResponse},
      unauthorized: {"Unauthorized", "application/json", Schemas.Error}
    ]
  )

  @spec list_invited(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def list_invited(conn, _params) do
    current_user = conn.assigns[:current_user]
    invited_users = InvitedUsers.list_invited_users(current_user)
    render(conn, "invited_users.json", invited_users: invited_users)
  end

  # This stops the user from changing the name of Personal organisation
  defp remove_name_from_params(%Organisation{name: "Personal"}, params),
    do: Map.delete(params, "name")

  defp remove_name_from_params(_, params), do: params
end
