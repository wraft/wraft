defmodule WraftDocWeb.Api.V1.StateController do
  use WraftDocWeb, :controller
  use PhoenixSwagger

  plug WraftDocWeb.Plug.AddActionLog

  plug WraftDocWeb.Plug.Authorized,
    create: "flow:manage",
    index: "flow:show",
    update: "flow:manage",
    delete: "flow:delete",
    add_user_to_state: "flow:manage",
    remove_user_from_state: "flow:delete"

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.Account.UserOrganisation
  alias WraftDoc.Documents
  alias WraftDoc.Documents.Instance
  alias WraftDoc.Enterprise
  alias WraftDoc.Enterprise.Flow
  alias WraftDoc.Enterprise.Flow.State
  alias WraftDoc.Enterprise.StateUser

  def swagger_definitions do
    %{
      StateRequest:
        swagger_schema do
          title("State Request")
          description("Create state request.")

          properties do
            state(:string, "State name", required: true)
            order(:integer, "State's order", required: true)
            type(:string, "State's type")
            approvers(:array, "State's approvers", required: true)
          end

          example(%{
            state: "Published",
            order: 1,
            type: "reviewer",
            approvers: [
              "b840c04c-25a2-4426-895a-acd2685153e4",
              "b190bece-160c-44cc-91e9-79367ed2ccf6"
            ]
          })
        end,
      UpdateStateRequest:
        swagger_schema do
          title("Update State Request")
          description("Update state request.")

          properties do
            state(:string, "State name")
            order(:integer, "State's order")
            type(:string, "State's type")
            approvers(:map, "State's approvers")
          end

          example(%{
            state: "Published",
            order: 3,
            type: "reviewer",
            approvers: %{
              add: [
                "b840c04c-25a2-4426-895a-acd2685153e4",
                "b190bece-160c-44cc-91e9-79367ed2ccf6"
              ],
              remove: [
                "b840c04c-25a2-4426-895a-acd2685153e4",
                "b190bece-160c-44cc-91e9-79367ed2ccf6"
              ]
            }
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
            type(:string, "Type of the state")
            inserted_at(:string, "When was the state inserted", format: "ISO-8601")
            updated_at(:string, "When was the state last updated", format: "ISO-8601")
          end

          example(%{
            id: "1232148nb3478",
            state: "published",
            order: 1,
            type: "reviewer",
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
              type: "reviewer",
              updated_at: "2020-01-21T14:00:00Z",
              inserted_at: "2020-02-21T14:00:00Z"
            },
            approvers: [
              "b840c04c-25a2-4426-895a-acd2685153e4",
              "b190bece-160c-44cc-91e9-79367ed2ccf6"
            ],
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
        end,
      FlowIndex:
        swagger_schema do
          properties do
            states(Schema.ref(:ShowStates))
          end

          example(%{
            states: [
              %{
                state: %{
                  id: "1232148nb3478",
                  state: "published",
                  order: 1,
                  type: "reviewer",
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
              }
            ]
          })
        end,
      StateUserDocumentLevelRequest:
        swagger_schema do
          properties do
            content_id(:string, "Document id", required: true)
          end

          example(%{
            content_id: "f0b206b0-94e5-4bcb-a87b-1656166d9ebb"
          })
        end,
      StateUserDocumentLevelResponse:
        swagger_schema do
          properties do
            users(Schema.ref(:User))
          end

          example(%{
            users: [
              %{
                id: "1232148nb3478",
                name: "John Doe",
                email: "email@xyz.com",
                email_verify: true,
                updated_at: "2020-01-21T14:00:00Z",
                inserted_at: "2020-02-21T14:00:00Z"
              }
            ]
          })
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

    with %Flow{} = flow <- Enterprise.get_flow(flow_id, current_user),
         %State{} = state <- Enterprise.create_state(current_user, flow, params) do
      render(conn, "state_with_approvers.json", state: state)
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

    response(200, "Ok", Schema.ref(:FlowIndex))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, %{"flow_id" => flow_uuid} = _params) do
    with states <- Enterprise.state_index(flow_uuid) do
      render(conn, "index.json", states: states)
    end
  end

  @doc """
  List users in a state
  """
  swagger_path :list_users_in_state do
    get("/states/{state_id}/users")
    summary("List users in a state")
    description("List users in a state")

    parameters do
      state_id(:path, :string, "state id", required: true)
      document_id(:query, :string, "document id", required: true)
    end

    response(200, "Ok", Schema.ref(:StateUserDocumentLevelResponse))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec list_users_in_state(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def list_users_in_state(conn, %{"state_id" => state_id, "document_id" => document_id}) do
    with users <- Enterprise.fetch_flow_state_users(state_id, document_id) do
      render(conn, "list_users_in_state.json", users: users)
    end
  end

  @doc """
  State update.
  """
  swagger_path :update do
    put("/states/{id}")
    summary("State update")
    description("API to update a state")

    parameters do
      id(:path, :string, "state id", required: true)
      state(:body, Schema.ref(:UpdateStateRequest), "State to be updated", required: true)
    end

    response(200, "Ok", Schema.ref(:ShowState))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not found", Schema.ref(:Error))
  end

  # TODO - Missing tests
  @spec update(Plug.Conn.t(), map) :: Plug.Conn.t()
  def update(conn, %{"id" => uuid} = params) do
    current_user = conn.assigns[:current_user]

    with %State{} = state <- Enterprise.get_state(current_user, uuid),
         %State{} = state <- Enterprise.update_state(state, params) do
      render(conn, "show.json", state: state)
    end
  end

  @doc """
  State delete.
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
    current_user = conn.assigns[:current_user]

    with %State{} = state <- Enterprise.get_state(current_user, uuid),
         {:ok, %State{}} <- Enterprise.delete_state(state) do
      Task.start(fn -> Enterprise.shuffle_order(state, -1) end)

      render(conn, "create.json", state: state)
    end
  end

  @doc """
    Add user to flow state at document level.
  """
  swagger_path :add_user_to_state do
    post("states/{state_id}/users/{user_id}")
    summary("Add user to state at document level")
    description("Add user to flow state at document level")

    parameters do
      state_id(:path, :string, "State id", required: true)
      user_id(:path, :string, "User id", required: true)

      document_id(
        :query,
        "string",
        "Document id",
        required: true
      )
    end

    response(200, "Ok", Schema.ref(:State))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec add_user_to_state(Plug.Conn.t(), map) :: Plug.Conn.t()
  def add_user_to_state(
        conn,
        %{"state_id" => state_id, "content_id" => document_id, "user_id" => user_id} = params
      ) do
    current_user = conn.assigns[:current_user]

    with %State{} = state <- Enterprise.get_state(current_user, state_id),
         %Instance{} = instance <- Documents.get_instance(document_id, current_user),
         %UserOrganisation{} <- Enterprise.get_user_organisation(current_user, user_id),
         nil <- Enterprise.get_state_user(user_id, state_id),
         %State{} = state <- Enterprise.add_user_to_state(instance, state, params) do
      render(conn, "state_with_approvers.json", state: state)
    end
  end

  @doc """
  Remove user from a flow state at document level.
  """
  swagger_path :remove_user_from_state do
    PhoenixSwagger.Path.delete("/states/{state_id}/users/{user_id}")
    summary("Remove user from state at document level")
    description("Remove user from flow state at document level")

    parameters do
      state_id(:path, :string, "State id", required: true)
      user_id(:path, :string, "User id", required: true)

      document_id(
        :query,
        "string",
        "Document id",
        required: true
      )
    end

    response(200, "Ok", Schema.ref(:State))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec remove_user_from_state(Plug.Conn.t(), map) :: Plug.Conn.t()
  def remove_user_from_state(conn, %{
        "state_id" => state_id,
        "content_id" => document_id,
        "user_id" => user_id
      }) do
    current_user = conn.assigns[:current_user]

    with %State{} = state <- Enterprise.get_state(current_user, state_id),
         %Instance{} = instance <- Documents.get_instance(document_id, current_user),
         %UserOrganisation{} <- Enterprise.get_user_organisation(current_user, user_id),
         %StateUser{} = state_user <- Enterprise.get_state_user(user_id, state_id, document_id),
         %State{} = state <- Enterprise.remove_user_from_state(instance, state, state_user) do
      render(conn, "state_with_approvers.json", state: state)
    end
  end
end
