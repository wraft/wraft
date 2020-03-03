defmodule WraftDocWeb.Api.V1.FlowController do
  use WraftDocWeb, :controller
  use PhoenixSwagger

  action_fallback(WraftDocWeb.FallbackController)
  alias WraftDoc.{Enterprise, Enterprise.Flow, Enterprise.Organisation}

  def swagger_definitions do
    %{
      FlowRequest:
        swagger_schema do
          title("Flow Request")
          description("Create flow request.")

          properties do
            state(:string, "State name", required: true)
            order(:integer, "State's order", required: true)
            organisation_uuid(:string, "Organisation ID", required: true)
          end

          example(%{
            state: "Published",
            order: 1,
            organisation_id: "nu123kmlj2348"
          })
        end,
      FlowUpdateRequest:
        swagger_schema do
          title("Flow update Request")
          description("Update flow request.")

          properties do
            state(:string, "State name", required: true)
            order(:integer, "State's order", required: true)
          end

          example(%{
            state: "Published",
            order: 1
          })
        end,
      Flow:
        swagger_schema do
          title("Flow")
          description("State assigened to contents")

          properties do
            id(:string, "ID of the flow")
            state(:string, "A state of content")
            order(:integer, "Order of the state")
          end

          example(%{
            id: "1232148nb3478",
            state: "published",
            order: 1
          })
        end,
      ShowFlow:
        swagger_schema do
          title("Show flow details")
          description("Show all details of a flow")

          properties do
            flow(Schema.ref(:Flow))
            creator(Schema.ref(:User))
          end

          example(%{
            flow: %{
              id: "1232148nb3478",
              state: "published",
              order: 1
            },
            creator: %{
              id: "1232148nb3478",
              name: "John Doe",
              email: "email@xyz.com",
              email_verify: true,
              updated_at: "2020-01-21T14:00:00Z",
              inserted_at: "2020-02-21T14:00:00Z"
            }
          })
        end,
      ShowFlows:
        swagger_schema do
          title("All flows and its details")
          description("All flows that have been created and their creators")
          type(:array)
          items(Schema.ref(:ShowFlow))
        end
    }
  end

  @doc """
  Create a flow.
  """
  swagger_path :create do
    post("/flows")
    summary("Create a flow")
    description("Create flow API")

    parameters do
      flow(:body, Schema.ref(:FlowRequest), "Flow to be created", required: true)
    end

    response(200, "Ok", Schema.ref(:Flow))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec create(Plug.Conn.t(), map) :: Plug.Conn.t()
  def create(conn, %{"organisation_uuid" => org_uuid} = params) do
    current_user = conn.assigns[:current_user]

    with %Organisation{} = organisation <- Enterprise.get_organisation(org_uuid),
         %Flow{} = flow <- Enterprise.create_flow(current_user, organisation, params) do
      conn |> render("flow.json", flow: flow)
    end
  end

  @doc """
  Flow index.
  """
  swagger_path :index do
    get("/flows")
    summary("Flow index")
    description("Index of flow")

    response(200, "Ok", Schema.ref(:ShowFlows))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec index(Plug.Conn.t(), map) :: Plug.Conn.t()
  def index(conn, _params) do
    flows = Enterprise.flow_index()

    conn
    |> render("index.json", flows: flows)
  end

  @doc """
  Flow update.
  """
  swagger_path :update do
    put("/flows/{id}")
    summary("Flow update")
    description("API to update a flow")

    parameters do
      id(:path, :string, "flow id", required: true)
      flow(:body, Schema.ref(:FlowUpdateRequest), "Flow to be created", required: true)
    end

    response(200, "Ok", Schema.ref(:ShowFlow))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not found", Schema.ref(:Error))
  end

  @spec update(Plug.Conn.t(), map) :: Plug.Conn.t()
  def update(conn, %{"id" => uuid} = params) do
    with %Flow{} = flow <- Enterprise.get_flow(uuid),
         %Flow{} = flow <- Enterprise.update_flow(flow, params) do
      conn
      |> render("show.json", flow: flow)
    end
  end

  @doc """
  Flow delete.
  """
  swagger_path :delete do
    PhoenixSwagger.Path.delete("/flows/{id}")
    summary("Flow delete")
    description("API to delete a flow")

    parameters do
      id(:path, :string, "flow id", required: true)
    end

    response(200, "Ok", Schema.ref(:Flow))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not found", Schema.ref(:Error))
  end

  @spec delete(Plug.Conn.t(), map) :: Plug.Conn.t()
  def delete(conn, %{"id" => uuid}) do
    with %Flow{} = flow <- Enterprise.get_flow(uuid),
         {:ok, %Flow{}} <- Enterprise.delete_flow(flow) do
      Task.start(fn -> Enterprise.shuffle_order(flow, -1) end)

      conn
      |> render("flow.json", flow: flow)
    end
  end
end
