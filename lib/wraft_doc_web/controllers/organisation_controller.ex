defmodule WraftDocWeb.Api.V1.OrganisationController do
  use WraftDocWeb, :controller
  use PhoenixSwagger
  alias WraftDoc.{Enterprise.Organisation, Enterprise}

  action_fallback(WraftDocWeb.FallbackController)

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

    parameters do
      organisation(:body, Schema.ref(:OrganisationRequest), "Organisation to create",
        required: true
      )
    end

    response(201, "Created", Schema.ref(:Organisation))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @doc """
  Createm new organisation
  """

  @spec create(Plug.Conn.t(), map) :: Plug.Conn.t()
  def create(conn, params) do
    current_user = conn.assigns.current_user

    with {:ok, %Organisation{} = organisation} <-
           Enterprise.create_organisation(current_user, params) do
      conn
      |> put_status(:created)
      |> render("create.json", organisation: organisation)
    end
  end

  @doc """
  Update an organisation
  """
  swagger_path :update do
    put("/organisations/{id}")
    summary("Update an organisation")
    description("API to update an organisation")

    parameters do
      id(:path, :string, "organisation id", required: true)

      organisation(:body, Schema.ref(:OrganisationRequest), "Organisation to be updated",
        required: true
      )
    end

    response(202, "Accepted", Schema.ref(:Organisation))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(404, "Not Found", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec update(Plug.Conn.t(), map) :: Plug.Conn.t()
  def update(conn, %{"id" => uuid} = params) do
    with %Organisation{} = organisation <- Enterprise.get_organisation(uuid),
         {:ok, %Organisation{}} <-
           Enterprise.update_organisation(organisation, params) do
      conn
      |> put_status(:created)
      |> render("create.json", organisation: organisation)
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
  def show(conn, %{"uuid" => uuid}) do
    with %Organisation{} = organisation <- Enterprise.get_organisation(uuid) do
      conn
      |> render("show.json", organisation: organisation)
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
  def delete(conn, %{"id" => uuid}) do
    with %Organisation{} = organisation <- Enterprise.get_organisation(uuid),
         {:ok, %Organisation{}} <- Enterprise.delete_organisation(organisation) do
      conn
      |> render("organisation.json", organisation: organisation)
    end
  end
end
