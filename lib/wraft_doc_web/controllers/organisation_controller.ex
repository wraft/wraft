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
  alias WraftDoc.Account.Role
  alias WraftDoc.Account.UserOrganisation
  alias WraftDoc.Enterprise
  alias WraftDoc.Enterprise.Organisation
  alias WraftDoc.InvitedUsers

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
          items(Schema.ref(:CurrentUser))
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
    parameter(:legal_name, :formData, :string, "Legal name of organisation", required: true)
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
        with %Organisation{id: id} = organisation <-
               Enterprise.create_organisation(current_user, params),
             {:ok, %Oban.Job{}} <-
               Enterprise.create_default_worker_job(
                 %{organisation_id: id, user_id: current_user.id},
                 "organisation_roles"
               ),
             {:ok, %Oban.Job{}} <-
               Enterprise.create_default_worker_job(
                 %{organisation_id: id},
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
    parameter(:legal_name, :formData, :string, "Legal name of organisation", required: true)
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
  def update(conn, %{"id" => id} = params) do
    with %Organisation{} = organisation <- Enterprise.get_organisation(id),
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
    case Enterprise.get_organisation(id) do
      %Organisation{} = organisation -> render(conn, "show.json", organisation: organisation)
      # TODO - Change this to use with statement and make sure it returns only 200, 404, and 401
      _ -> {:error, :invalid_id}
    end
  end

  @doc """
  Delete an organisation
  """
  swagger_path :delete do
    PhoenixSwagger.Path.delete("/organisations/{id}")
    summary("Delete an organisation")
    description("Delete Organisation API")
    operation_id("delete_organisation")
    tag("Organisation")

    parameters do
      id(:path, :string, "Organisation id", required: true)
    end

    response(200, "Ok", Schema.ref(:Organisation))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not Found", Schema.ref(:Error))
  end

  @spec delete(Plug.Conn.t(), map) :: Plug.Conn.t()
  def delete(conn, %{"id" => id}) do
    with %Organisation{} = organisation <- Enterprise.get_organisation(id),
         {:ok, %Organisation{}} <- Enterprise.delete_organisation(organisation) do
      render(conn, "organisation.json", organisation: organisation)
    end
  end

  @doc """
  Invite new member.
  """
  swagger_path :invite do
    post("/organisations/users/invite")
    summary("Invite new member to the organisation")
    description("Invite new member to the organisation")
    consumes("multipart/form-data")

    parameters do
      email(:formData, :string, "Email of the user", required: true)
      role_id(:formData, :string, "role of the user", required: true)
    end

    response(200, "Ok", Schema.ref(:InvitedResponse))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not Found", Schema.ref(:Error))
  end

  def invite(conn, params) do
    current_user = conn.assigns[:current_user]

    with %Organisation{} = organisation <-
           Enterprise.get_organisation(current_user.current_org_id),
         :ok <- Enterprise.already_member(current_user.current_org_id, params["email"]),
         %Role{} = role <-
           Account.get_role(current_user, params["role_id"]),
         {:ok, _} <-
           Enterprise.invite_team_member(current_user, organisation, params["email"], role) do
      FunWithFlags.enable(:waiting_list_registration_control,
        for_actor: %{email: params["email"]}
      )

      InvitedUsers.create_or_update_invited_user(params["email"], organisation.id)

      render(conn, "invite.json")
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

  # swagger_path :search do
  #   get("/organisations")
  #   summary("Search organisation")
  #   description("Search and list organisation by name")

  #   parameters do
  #     name(:query, :string, "Organisations name")
  #     page(:query, :string, "Page number")
  #   end

  #   response(200, "Ok", Schema.ref(:Index))
  #   response(422, "Unprocessable Entity", Schema.ref(:Error))
  #   response(401, "Unauthorized", Schema.ref(:Error))
  #   response(404, "Not Found", Schema.ref(:Error))
  # end

  # def search(conn, params) do
  #   with %{
  #          entries: organisations,
  #          page_number: page_number,
  #          total_pages: total_pages,
  #          total_entries: total_entries
  #        } <- Enterprise.search_organisations(params) do
  #     conn
  #     |> render("index.json",
  #       organisations: organisations,
  #       page_number: page_number,
  #       total_pages: total_pages,
  #       total_entries: total_entries
  #     )
  #   end
  # end
end
