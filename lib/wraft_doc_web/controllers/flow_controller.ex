defmodule WraftDocWeb.Api.V1.FlowController do
  use WraftDocWeb, :controller
  use PhoenixSwagger
  plug(WraftDocWeb.Plug.Authorized)
  plug(WraftDocWeb.Plug.AddActionLog)
  action_fallback(WraftDocWeb.FallbackController)
  alias WraftDoc.{Enterprise, Enterprise.Flow}

  def swagger_definitions do
    %{
      FlowRequest:
        swagger_schema do
          title("Flow Request")
          description("Create flow request.")

          properties do
            name(:string, "Flow's name", required: true)
          end

          example(%{
            name: "Flow 1"
          })
        end,
      Flow:
        swagger_schema do
          title("Flow")
          description("Flows to be followed in an organisation")

          properties do
            id(:string, "ID of the flow")
            name(:string, "Name of the flow")
            inserted_at(:string, "When was the flow inserted", format: "ISO-8601")
            updated_at(:string, "When was the flow last updated", format: "ISO-8601")
          end

          example(%{
            id: "1232148nb3478",
            name: "Flow 1",
            updated_at: "2020-01-21T14:00:00Z",
            inserted_at: "2020-02-21T14:00:00Z"
          })
        end,
      UpdateFlow:
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
              name: "Flow 1",
              updated_at: "2020-01-21T14:00:00Z",
              inserted_at: "2020-02-21T14:00:00Z"
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
          description("All flows that have been created and their details")
          type(:array)
          items(Schema.ref(:UpdateFlow))
        end,
      FlowAndStates:
        swagger_schema do
          title("Show flow details and its states")
          description("Show all details of a flow including all the states undet the flow")

          properties do
            flow(Schema.ref(:Flow))
            creator(Schema.ref(:User))
            states(Schema.ref(:State))
          end

          example(%{
            flow: %{
              id: "1232148nb3478",
              name: "Flow 1",
              updated_at: "2020-01-21T14:00:00Z",
              inserted_at: "2020-02-21T14:00:00Z"
            },
            creator: %{
              id: "1232148nb3478",
              name: "John Doe",
              email: "email@xyz.com",
              email_verify: true,
              updated_at: "2020-01-21T14:00:00Z",
              inserted_at: "2020-02-21T14:00:00Z"
            },
            states: [
              %{
                id: "1232148nb3478",
                state: "published",
                order: 1
              }
            ]
          })
        end,
      FlowAndStatesWithoutCreator:
        swagger_schema do
          title("Show flow details and its states")
          description("Show all details of a flow including all the states undet the flow")

          properties do
            flow(Schema.ref(:Flow))
            states(Schema.ref(:State))
          end

          example(%{
            flow: %{
              id: "1232148nb3478",
              name: "Flow 1",
              updated_at: "2020-01-21T14:00:00Z",
              inserted_at: "2020-02-21T14:00:00Z"
            },
            states: [
              %{
                id: "1232148nb3478",
                state: "published",
                order: 1
              }
            ]
          })
        end,
      FlowIndex:
        swagger_schema do
          properties do
            flows(Schema.ref(:ShowFlows))
            page_number(:integer, "Page number")
            total_pages(:integer, "Total number of pages")
            total_entries(:integer, "Total number of contents")
          end

          example(%{
            flows: [
              %{
                flow: %{
                  id: "1232148nb3478",
                  name: "Flow 1",
                  updated_at: "2020-01-21T14:00:00Z",
                  inserted_at: "2020-02-21T14:00:00Z"
                },
                creator: %{
                  id: "1232148nb3478",
                  name: "John Doe",
                  email: "email@xyz.com",
                  email_verify: true,
                  updated_at: "2020-01-21T14:00:00Z",
                  inserted_at: "2020-02-21T14:00:00Z"
                }
              }
            ],
            page_number: 1,
            total_pages: 2,
            total_entries: 15
          })
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
  def create(conn, params) do
    current_user = conn.assigns[:current_user]

    with %Flow{} = flow <-
           Enterprise.create_flow(current_user, params) do
      Task.start_link(fn -> Enterprise.create_default_states(current_user, flow) end)

      conn |> render("flow.json", flow: flow)
    end
  end

  @doc """
  Flow index.
  """
  swagger_path :index do
    get("/flows")
    summary("Flow index")
    description("Index of flows in current user's organisation")

    parameter(:page, :query, :string, "Page number")

    response(200, "Ok", Schema.ref(:FlowIndex))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec index(Plug.Conn.t(), map) :: Plug.Conn.t()
  def index(conn, params) do
    current_user = conn.assigns[:current_user]

    with %{
           entries: flows,
           page_number: page_number,
           total_pages: total_pages,
           total_entries: total_entries
         } <- Enterprise.flow_index(current_user, params) do
      conn
      |> render("index.json",
        flows: flows,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      )
    end
  end

  @doc """
  Show Flow.
  """
  swagger_path :show do
    get("/flows/{id}")
    summary("Show a flow")
    description("Show a flow and its details including states under it")

    parameters do
      id(:path, :string, "flow id", required: true)
    end

    response(200, "Ok", Schema.ref(:FlowAndStates))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec show(Plug.Conn.t(), map) :: Plug.Conn.t()
  def show(conn, %{"id" => flow_uuid}) do
    with %Flow{} = flow <- Enterprise.show_flow(flow_uuid) do
      conn
      |> render("show.json", flow: flow)
    end
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
      flow(:body, Schema.ref(:FlowRequest), "Flow to be updated", required: true)
    end

    response(200, "Ok", Schema.ref(:UpdateFlow))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not found", Schema.ref(:Error))
  end

  @spec update(Plug.Conn.t(), map) :: Plug.Conn.t()
  def update(conn, %{"id" => uuid} = params) do
    current_user = conn.assigns[:current_user]

    with %Flow{} = flow <- Enterprise.get_flow(uuid),
         %Flow{} = flow <- Enterprise.update_flow(flow, current_user, params) do
      conn
      |> render("update.json", flow: flow)
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
    current_user = conn.assigns[:current_user]

    with %Flow{} = flow <- Enterprise.get_flow(uuid),
         {:ok, %Flow{}} <- Enterprise.delete_flow(flow, current_user) do
      conn
      |> render("flow.json", flow: flow)
    end
  end
end
