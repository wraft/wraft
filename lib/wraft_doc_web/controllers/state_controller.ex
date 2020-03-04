defmodule WraftDocWeb.Api.V1.StateController do
  use WraftDocWeb, :controller
  use PhoenixSwagger

  action_fallback(WraftDocWeb.FallbackController)
  alias WraftDoc.{Enterprise, Enterprise.Flow, Enterprise.Flow.State}

  def swagger_definitions do
    %{
      StateRequest:
        swagger_schema do
          title("State Request")
          description("Create state request.")

          properties do
            state(:string, "State name", required: true)
            order(:integer, "State's order", required: true)
          end

          example(%{
            state: "Published",
            order: 1
          })
        end,
      State:
        swagger_schema do
          title("State")
          description("State assigened to contents")

          properties do
            id(:string, "ID of the state")
            state(:string, "A state of content")
            order(:integer, "Order of the state")
            inserted_at(:string, "When was the state inserted", format: "ISO-8601")
            updated_at(:string, "When was the state last updated", format: "ISO-8601")
          end

          example(%{
            id: "1232148nb3478",
            state: "published",
            order: 1,
            updated_at: "2020-01-21T14:00:00Z",
            inserted_at: "2020-02-21T14:00:00Z"
          })
        end,
      ShowState:
        swagger_schema do
          title("Show flow details")
          description("Show all details of a flow")

          properties do
            state(Schema.ref(:State))
            creator(Schema.ref(:User))
            flow(Schema.ref(:Flow))
          end

          example(%{
            state: %{
              id: "1232148nb3478",
              state: "published",
              order: 1,
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
            flow: %{
              id: "jnb234881adsad",
              name: "Flow 1",
              updated_at: "2020-01-21T14:00:00Z",
              inserted_at: "2020-02-21T14:00:00Z"
            }
          })
        end,
      ShowStates:
        swagger_schema do
          title("All states and its details")
          description("All states that have been created and their details")
          type(:array)
          items(Schema.ref(:ShowState))
        end
    }
  end

  @doc """
  Create a state.
  """
  swagger_path :create do
    post("/flows/{flow_id}/states")
    summary("Create a state")
    description("Create state API")

    parameters do
      state(:body, Schema.ref(:StateRequest), "State to be created", required: true)
      flow_id(:path, :string, "Flow id", required: true)
    end

    response(200, "Ok", Schema.ref(:State))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec create(Plug.Conn.t(), map) :: Plug.Conn.t()
  def create(conn, %{"flow_id" => flow_id} = params) do
    current_user = conn.assigns[:current_user]

    with %Flow{} = flow <- Enterprise.get_flow(flow_id),
         {:ok, %State{} = state} <- Enterprise.create_state(current_user, flow, params) do
      conn |> render("create.json", state: state)
    end
  end

  @doc """
  State index.
  """
  swagger_path :index do
    get("/flows/{flow_id}/states")
    summary("State index")
    description("Index of States under a flow")

    parameters do
      flow_id(:path, :string, "flow id", required: true)
    end

    response(200, "Ok", Schema.ref(:ShowStates))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec index(Plug.Conn.t(), map) :: Plug.Conn.t()
  def index(conn, %{"flow_id" => flow_uuid}) do
    states = Enterprise.state_index(flow_uuid)

    conn
    |> render("index.json", states: states)
  end

  @doc """
  Flow update.
  """
  swagger_path :update do
    put("/states/{id}")
    summary("State update")
    description("API to update a state")

    parameters do
      id(:path, :string, "state id", required: true)
      flow(:body, Schema.ref(:StateRequest), "Flow to be created", required: true)
    end

    response(200, "Ok", Schema.ref(:ShowState))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not found", Schema.ref(:Error))
  end

  @spec update(Plug.Conn.t(), map) :: Plug.Conn.t()
  def update(conn, %{"id" => uuid} = params) do
    with %State{} = state <- Enterprise.get_state(uuid),
         %State{} = %State{} = state <- Enterprise.update_state(state, params) do
      conn
      |> render("show.json", state: state)
    end
  end

  @doc """
  Flow delete.
  """
  swagger_path :delete do
    PhoenixSwagger.Path.delete("/states/{id}")
    summary("State delete")
    description("API to delete a state")

    parameters do
      id(:path, :string, "state id", required: true)
    end

    response(200, "Ok", Schema.ref(:State))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not found", Schema.ref(:Error))
  end

  @spec delete(Plug.Conn.t(), map) :: Plug.Conn.t()
  def delete(conn, %{"id" => uuid}) do
    with %State{} = state <- Enterprise.get_state(uuid),
         {:ok, %State{}} <- Enterprise.delete_state(state) do
      Task.start(fn -> Enterprise.shuffle_order(state, -1) end)

      conn
      |> render("create.json", state: state)
    end
  end
end