defmodule WraftDocWeb.Api.V1.StateController do
  use WraftDocWeb, :controller
  use OpenApiSpex.ControllerSpecs

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
  alias WraftDocWeb.Schemas.Error
  alias WraftDocWeb.Schemas.State, as: StateSchema

  tags(["states"])

  operation(:create,
    summary: "Create a state",
    description: "Create state API",
    parameters: [
      flow_id: [in: :path, type: :string, description: "Flow id", required: true]
    ],
    request_body: {"State to be created", "application/json", StateSchema.StateRequest},
    responses: [
      ok: {"Ok", "application/json", StateSchema.State},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  @spec create(Plug.Conn.t(), map) :: Plug.Conn.t()
  def create(conn, %{"flow_id" => flow_id} = params) do
    current_user = conn.assigns[:current_user]

    with %Flow{} = flow <- Enterprise.get_flow(flow_id, current_user),
         %State{} = state <- Enterprise.create_state(current_user, flow, params) do
      render(conn, "state_with_approvers.json", state: state)
    end
  end

  operation(:index,
    summary: "State index",
    description: "Index of States under a flow",
    parameters: [
      flow_id: [in: :path, type: :string, description: "flow id", required: true]
    ],
    responses: [
      ok: {"Ok", "application/json", StateSchema.FlowIndex},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, %{"flow_id" => flow_uuid} = _params) do
    with states <- Enterprise.state_index(flow_uuid) do
      render(conn, "index.json", states: states)
    end
  end

  operation(:list_users_in_state,
    summary: "List users in a state",
    description: "List users in a state",
    parameters: [
      state_id: [in: :path, type: :string, description: "state id", required: true],
      document_id: [in: :query, type: :string, description: "document id", required: true]
    ],
    responses: [
      ok: {"Ok", "application/json", StateSchema.StateUserDocumentLevelResponse},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  @spec list_users_in_state(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def list_users_in_state(conn, %{"state_id" => state_id, "document_id" => document_id}) do
    with users <- Enterprise.fetch_flow_state_users(state_id, document_id) do
      render(conn, "list_users_in_state.json", users: users)
    end
  end

  operation(:update,
    summary: "State update",
    description: "API to update a state",
    parameters: [
      id: [in: :path, type: :string, description: "state id", required: true]
    ],
    request_body: {"State to be updated", "application/json", StateSchema.UpdateStateRequest},
    responses: [
      ok: {"Ok", "application/json", StateSchema.ShowState},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error},
      not_found: {"Not found", "application/json", Error}
    ]
  )

  # TODO - Missing tests
  @spec update(Plug.Conn.t(), map) :: Plug.Conn.t()
  def update(conn, %{"id" => uuid} = params) do
    current_user = conn.assigns[:current_user]

    with %State{} = state <- Enterprise.get_state(current_user, uuid),
         %State{} = state <- Enterprise.update_state(state, params) do
      render(conn, "show.json", state: state)
    end
  end

  operation(:delete,
    summary: "State delete",
    description: "API to delete a state",
    parameters: [
      id: [in: :path, type: :string, description: "state id", required: true]
    ],
    responses: [
      ok: {"Ok", "application/json", StateSchema.State},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error},
      not_found: {"Not found", "application/json", Error}
    ]
  )

  @spec delete(Plug.Conn.t(), map) :: Plug.Conn.t()
  def delete(conn, %{"id" => uuid}) do
    current_user = conn.assigns[:current_user]

    with %State{} = state <- Enterprise.get_state(current_user, uuid),
         {:ok, %State{}} <- Enterprise.delete_state(state) do
      Task.start(fn -> Enterprise.shuffle_order(state, -1) end)

      render(conn, "create.json", state: state)
    end
  end

  operation(:add_user_to_state,
    summary: "Add user to state at document level",
    description: "Add user to flow state at document level",
    parameters: [
      state_id: [in: :path, type: :string, description: "State id", required: true],
      user_id: [in: :path, type: :string, description: "User id", required: true],
      document_id: [in: :query, type: :string, description: "Document id", required: true]
    ],
    responses: [
      ok: {"Ok", "application/json", StateSchema.State},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

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

  operation(:remove_user_from_state,
    summary: "Remove user from state at document level",
    description: "Remove user from flow state at document level",
    parameters: [
      state_id: [in: :path, type: :string, description: "State id", required: true],
      user_id: [in: :path, type: :string, description: "User id", required: true],
      document_id: [in: :query, type: :string, description: "Document id", required: true]
    ],
    responses: [
      ok: {"Ok", "application/json", StateSchema.State},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

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
