defmodule WraftDocWeb.Api.V1.OrganisationController do
  use WraftDocWeb, :controller
  use PhoenixSwagger

  plug WraftDocWeb.Plug.AddActionLog

  plug WraftDocWeb.Plug.Authorized,
    update: "organisation:update",
    show: "organisation:show",
    delete: "organisation:delete",
    invite: "members:manage",
    members: "organisation:members",
    index: "organisation:show",
    remove_user: "members:manage"

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.Account
  alias WraftDoc.Account.User
  alias WraftDoc.Account.UserOrganisation
  alias WraftDoc.AuthTokens
  alias WraftDoc.AuthTokens.AuthToken
  alias WraftDoc.Enterprise
  alias WraftDoc.Enterprise.Flow
  alias WraftDoc.Enterprise.Organisation
  alias WraftDoc.InvitedUsers
  alias WraftDocWeb.Guardian

  def swagger_definitions do
    %{
      OrganisationRequest:
        swagger_schema do
          title("Organisation Request")
          description("An organisation to be register for enterprice operation")

          properties do
            name(:string, "Organisation name", required: true)
            legal_name(:string, "Legal name of organisation", required: true)
            address(:string, "Address of organisation")
            gstin(:string, "Goods and service tax invoice numger")
            email(:string, "Official email")
            phone(:string, "Offical Phone number")
          end

          example(%{
            name: "ABC enterprices",
            legal_name: "ABC enterprices LLC",
            address: "#24, XV Building, TS DEB Layout ",
            gstin: "32AA65FF56545353",
            email: "abcent@gmail.com",
            phone: "865623232"
          })
        end,
      Organisation:
        swagger_schema do
          title("Organisation")
          description("An Organisation")

          properties do
            id(:string, "The id of an organisation", required: true)
            name(:string, "Name of the organisation", required: true)
            legal_name(:string, "Legal Name of the organisation", required: true)
            address(:string, "Address of the organisation")
            name_of_ceo(:string, "Organisation CEO's Name")
            name_of_cto(:string, "Organisation CTO's Name")
            gstin(:string, "GSTIN of organisation")
            corporate_id(:string, "Corporate id of organisation")
            members_count(:integer, "Number of members")
            phone(:strign, "Phone number of organisation")
            email(:string, "Email of organisation")
            logo(:string, "Logo of organisation")
            inserted_at(:string, "When was the user inserted", format: "ISO-8601")
            updated_at(:string, "When was the user last updated", format: "ISO-8601")
          end

          example(%{
            id: "mnbjhb23488n23e",
            name: "ABC enterprices",
            legal_name: "ABC enterprices LLC",
            address: "#24, XV Building, TS DEB Layout ",
            name_of_ceo: "John Doe",
            name_of_cto: "Foo Doo",
            gstin: "32AA65FF56545353",
            corporate_id: "BNIJSN1234NGT",
            members_count: 6,
            email: "abcent@gmail.com",
            logo: "/logo.jpg",
            phone: "865623232",
            updated_at: "2020-01-21T14:00:00Z",
            inserted_at: "2020-02-21T14:00:00Z"
          })
        end,
      InvitedResponse:
        swagger_schema do
          title("Invite user response")
          description("Invite user response")

          properties do
            info(:string, "Info", required: true)
          end

          example(%{info: "Invited successfully.!"})
        end,
      InviteTokenStatusResponse:
        swagger_schema do
          title("Invite Token Status")
          description("Invite Token Status")

          properties do
            isNewUser(:boolean, "Invite token status", required: true)
            email(:string, "Email of the user", required: true)
          end

          example(%{
            isNewUser: true,
            email: "abcent@gmail.com"
          })
        end,
      ListOfOrganisations:
        swagger_schema do
          title("Organisations array")
          description("List of existing Organisations")
          type(:array)
          items(Schema.ref(:Organisation))
        end,
      Index:
        swagger_schema do
          title("Organisation index")

          properties do
            organisations(Schema.ref(:ListOfOrganisations))
            page_number(:integer, "Page number")
            total_pages(:integer, "Total number of pages")
            toal_entries(:integer, "Total number of contents")
          end

          example(%{
            organisations: [
              %{
                id: "mnbjhb23488n23e",
                name: "ABC enterprices",
                legal_name: "ABC enterprices LLC",
                address: "#24, XV Building, TS DEB Layout ",
                name_of_ceo: "John Doe",
                name_of_cto: "Foo Doo",
                gstin: "32AA65FF56545353",
                corporate_id: "BNIJSN1234NGT",
                email: "abcent@gmail.com",
                logo: "/logo.jpg",
                phone: "865623232",
                updated_at: "2020-01-21T14:00:00Z",
                inserted_at: "2020-02-21T14:00:00Z"
              }
            ],
            page_number: 1,
            total_pages: 1,
            total_entries: 1
          })
        end,
      Members:
        swagger_schema do
          title("Members array")
          description("List of Users/members of an organisation.")
          type(:array)
          items(Schema.ref(:ShowCurrentUser))
        end,
      MembersIndex:
        swagger_schema do
          title("Members index")

          properties do
            members(Schema.ref(:Members))
            page_number(:integer, "Page number")
            total_pages(:integer, "Total number of pages")
            total_entries(:integer, "Total number of contents")
          end
        end,
      RemoveUser:
        swagger_schema do
          title("Remove User")
          description("Removes the user from the organisation")

          properties do
            info(:string, "Info", required: true)
          end

          example(%{info: "User removed from the organisation.!"})
        end,
      DeleteOrganisationRequest:
        swagger_schema do
          title("Delete Confirmation Token")
          description("Request body to delete an organisation")

          properties do
            token(:string, "Token", required: true)
          end

          example(%{
            code: "123456"
          })
        end,
      PermissionsResponse:
        swagger_schema do
          title("Current User Permissions")
          description("Current user permissions of current organisation")
          type(:map)

          example(%{
            permissions: %{
              asset: [
                "show",
                "manage",
                "delete"
              ],
              block: [
                "show",
                "manage",
                "delete"
              ]
            }
          })
        end,
      DeletionRequestResponse:
        swagger_schema do
          title("Delete Confirmation Code")
          description("Delete Confirmation Code Response")

          properties do
            info(:string, "Response Info")
          end

          example(%{
            info: "Delete token email sent!"
          })
        end,
      VerifyOrganisationInviteTokenResponse:
        swagger_schema do
          title("Verify Organisation invite token")

          description(
            "Verifies Organisation invite token and returns organisation details and user's details"
          )

          properties do
            organisation(Schema.ref(:Organisation))
          end
        end,
      InviteRequest:
        swagger_schema do
          title("Invite user")
          description("Request body to invite a user to an organisation")

          properties do
            email(:string, "Email of the user", required: true)
            role_ids(:array, "IDs of roles for the user", required: true)
          end

          example(%{
            email: "abcent@gmail.com",
            role_ids: ["756f1fa1-9657-4166-b372-21e8135aeaf1"]
          })
        end
    }
  end

  @doc """
  New registration
  """
  swagger_path :create do
    post("/organisations")
    summary("Register organisation")
    description("Create Organisation API")
    operation_id("create_organisation")
    tag("Organisation")
    consumes("multipart/form-data")
    parameter(:name, :formData, :string, "Organisation name", required: true)
    parameter(:legal_name, :formData, :string, "Legal name of organisation")
    parameter(:address, :formData, :string, "address of organisation")
    parameter(:name_of_ceo, :formData, :string, "name of ceo of organisation")
    parameter(:name_of_cto, :formData, :string, "name of cto of organisation")
    parameter(:gstin, :formData, :string, "gstin of organisation")
    parameter(:corporate_id, :formData, :string, "Corporate id of organisation")
    parameter(:email, :formData, :string, "Official email")
    parameter(:logo, :formData, :file, "Logo of organisation")
    parameter(:phone, :formData, :string, "Official ph number")
    parameter(:url, :formData, :string, "URL of organisation")
    response(201, "Created", Schema.ref(:Organisation))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

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
             {:ok, %Flow{}} <-
               Enterprise.create_flow(Map.put(current_user, :current_org_id, organisation_id), %{
                 "name" => "Wraft Flow",
                 "organisation_id" => organisation_id
               }),
             {:ok, %Oban.Job{}} <-
               Enterprise.create_default_worker_job(
                 %{organisation_id: organisation_id},
                 "wraft_theme_and_layout"
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
  swagger_path :update do
    put("/organisations/{id}")
    summary("Update an organisation")
    consumes("multipart/form-data")
    description("API to update an organisation")
    parameter(:id, :path, :string, "organisation id", required: true)
    parameter(:name, :formData, :string, "Organisation name", required: true)
    parameter(:legal_name, :formData, :string, "Legal name of organisation")
    parameter(:addres, :formData, :string, "address of organisation")
    parameter(:name_of_ceo, :formData, :string, "name of ceo of organisation")
    parameter(:name_of_cto, :formData, :string, "name of cto of organisation")
    parameter(:gstin, :formData, :string, "gstin of organisation")
    parameter(:corporate_id, :formData, :string, "Corporate id of organisation")
    parameter(:email, :formData, :string, "Official email")
    parameter(:logo, :formData, :file, "Logo of organisation")
    parameter(:phone, :formData, :string, "Official ph number")
    parameter(:url, :formData, :string, "URL of organisation")

    response(201, "Accepted", Schema.ref(:Organisation))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(404, "Not Found", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

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
  swagger_path :show do
    get("/organisations/{id}")
    summary("Show an Organisation")
    description("API to show details of an organisation")

    parameters do
      id(:path, :string, "Organisation id", required: true)
    end

    response(200, "Ok", Schema.ref(:Organisation))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not Found", Schema.ref(:Error))
  end

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
  swagger_path :delete do
    PhoenixSwagger.Path.delete("/organisations")
    summary("Delete an organisation")
    description("Delete Organisation API")
    operation_id("delete_organisation")
    tag("Organisation")

    parameters do
      delete_token(
        :body,
        Schema.ref(:DeleteOrganisationRequest),
        "Deletion Confirmation code",
        required: true
      )
    end

    response(200, "Ok", Schema.ref(:Organisation))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not Found", Schema.ref(:Error))
  end

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
  swagger_path :request_deletion do
    post("/organisations/request_deletion")
    summary("Organisation Deletion Code")
    description("Request Organisation Deletion Code")
    operation_id("request_organisation_deletion")
    tag("Organisation")

    response(200, "Ok", Schema.ref(:DeletionRequestResponse))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not Found", Schema.ref(:Error))
  end

  @spec request_deletion(Plug.Conn.t(), map) :: Plug.Conn.t()
  def request_deletion(conn, _params) do
    %{current_org_id: organisation_id, email: email} = current_user = conn.assigns.current_user

    with {:error, :already_member} <- Enterprise.already_member(organisation_id, email),
         %Organisation{name: name} = organisation when name != "Personal" <-
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
  swagger_path :invite do
    post("/organisations/users/invite")
    summary("Invite new member to the organisation")
    description("Invite new member to the organisation")

    parameters do
      invite(:body, Schema.ref(:InviteRequest), "Invite request", required: true)
    end

    response(200, "Ok", Schema.ref(:InvitedResponse))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not Found", Schema.ref(:Error))
  end

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

      InvitedUsers.create_or_update_invited_user(params["email"], organisation.id)

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
  List all members of a organisation
  """

  swagger_path :members do
    get("/organisations/{id}/members")
    summary("Members of an organisation")
    description("All members of an organisation")

    parameters do
      id(:path, :string, "ID of the organisation")
      page(:query, :string, "Page number")
      name(:query, :string, "Name of the user")
      role(:query, :string, "Name of the role")
      sort(:query, :string, "Sort Keys => name, name_desc, joined_at, joined_at_desc")
    end

    response(200, "Ok", Schema.ref(:MembersIndex))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not Found", Schema.ref(:Error))
  end

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

  swagger_path :index do
    get("/organisations")
    summary("List of all organisations")
    description("All organisation that we have")

    parameters do
      name(:query, :string, "Organisations name")
      page(:query, :string, "Page number")
    end

    response(200, "Ok", Schema.ref(:Index))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not Found", Schema.ref(:Error))
  end

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

  swagger_path :remove_user do
    post("/organisations/remove_user/{id}")
    summary("Api to remove a user from the given organisation")
    description("Api to remove a user from an organisation")

    parameters do
      id(:path, :string, "User id")
    end

    response(200, "ok", Schema.ref(:RemoveUser))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(404, "Not Found", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @doc """
    Remove a user from the organisation
  """
  @spec remove_user(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def remove_user(conn, %{"id" => user_id}) do
    current_user = conn.assigns[:current_user]

    with %UserOrganisation{} = user_organisation <-
           Enterprise.get_user_organisation(current_user, user_id),
         {:ok, %UserOrganisation{}} <- Enterprise.remove_user(user_organisation) do
      render(conn, "remove_user.json")
    end
  end

  swagger_path :verify_invite_token do
    get("/organisations/verify_invite_token/{token}")
    summary("Verify invite token")
    description("Api to verify organisation invite token")

    parameters do
      token(:path, :string, "Invite token")
    end

    response(200, "Ok", Schema.ref(:VerifyOrganisationInviteTokenResponse))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not Found", Schema.ref(:Error))
  end

  @doc """
    Verify organisation invite token
  """
  @spec verify_invite_token(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def verify_invite_token(conn, %{"token" => token}) do
    with {:ok, %{organisation_id: organisation_id, email: email}} <-
           AuthTokens.check_token(token, :invite),
         %Organisation{} = organisation <- Enterprise.get_organisation(organisation_id) do
      render(conn, "verify_invite_token.json",
        organisation: organisation,
        email: email
      )
    end
  end

  swagger_path :invite_token_status do
    get("/organisations/invite_token_status/{token}")
    summary("Invite token status")
    description("API to get invite token status")

    parameters do
      token(:path, :string, "Invite token")
    end

    response(200, "Ok", Schema.ref(:InviteTokenStatusResponse))
    response(404, "Not Found", Schema.ref(:Error))
  end

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
  swagger_path :permissions do
    get("/organisations/users/permissions")
    summary("user's permissions list")
    description("Api to get the permissions list of the user in current organisation")

    response(200, "Ok", Schema.ref(:PermissionsResponse))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  # TODO Write tests
  @spec permissions(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def permissions(conn, _params) do
    current_user = conn.assigns[:current_user]
    permissions = Enterprise.get_permissions(current_user)
    render(conn, "permissions.json", permissions: permissions)
  end

  # This stops the user from changing the name of Personal organisation
  defp remove_name_from_params(%Organisation{name: "Personal"}, params),
    do: Map.delete(params, "name")

  defp remove_name_from_params(_, params), do: params
end
