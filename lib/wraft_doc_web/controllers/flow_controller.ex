defmodule WraftDocWeb.Api.V1.FlowController do
  use WraftDocWeb, :controller
  use OpenApiSpex.ControllerSpecs

  plug WraftDocWeb.Plug.AddActionLog

  plug WraftDocWeb.Plug.Authorized,
    create: "flow:manage",
    index: "flow:show",
    show: "flow:show",
    update: "flow:manage",
    align_states: "flow:manage",
    delete: "flow:delete"

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.Enterprise
  alias WraftDoc.Enterprise.Flow
  alias WraftDoc.Search.TypesenseServer, as: Typesense
  alias WraftDocWeb.Schemas.Error
  alias WraftDocWeb.Schemas.Flow, as: FlowSchema

  tags(["Flows"])

  operation(:create,
    summary: "Create a flow",
    description: "Create flow API",
    parameters: [],
    request_body: {"Flow to be created", "application/json", FlowSchema.ControlledFlowRequest},
    responses: [
      ok: {"Ok", "application/json", FlowSchema.FlowBase},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  @spec create(Plug.Conn.t(), map) :: Plug.Conn.t()
  def create(conn, params) do
    current_user = conn.assigns[:current_user]

    with {:ok, %Flow{} = flow} <-
           Enterprise.create_flow(current_user, params) do
      Typesense.create_document(flow)
      render(conn, "flow.json", flow: flow)
    end
  end

  operation(:index,
    summary: "Flow index",
    description: "Index of flows in current user's organisation",
    parameters: [
      page: [in: :query, type: :string, description: "Page number"],
      name: [in: :query, type: :string, description: "Flow Name"],
      sort: [
        in: :query,
        type: :string,
        description:
          "sort keys => name, name_desc, inserted_at, inserted_at_desc, updated_at, updated_at_desc"
      ]
    ],
    responses: [
      ok: {"Ok", "application/json", FlowSchema.FlowIndex},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  @spec index(Plug.Conn.t(), map) :: Plug.Conn.t()
  def index(conn, params) do
    current_user = conn.assigns[:current_user]

    with %{
           entries: flows,
           page_number: page_number,
           total_pages: total_pages,
           total_entries: total_entries
         } <- Enterprise.flow_index(current_user, params) do
      render(conn, "index.json",
        flows: flows,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      )
    end
  end

  operation(:show,
    summary: "Show a flow",
    description: "Show a flow and its details including states under it",
    parameters: [
      id: [in: :path, type: :string, description: "flow id", required: true]
    ],
    responses: [
      ok: {"Ok", "application/json", FlowSchema.FlowFull},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  @spec show(Plug.Conn.t(), map) :: Plug.Conn.t()
  def show(conn, %{"id" => flow_id}) do
    current_user = conn.assigns.current_user

    with %Flow{} = flow <- Enterprise.show_flow(flow_id, current_user) do
      render(conn, "show.json", flow: flow)
    end
  end

  operation(:update,
    summary: "Flow update",
    description: "API to update a flow",
    parameters: [
      id: [in: :path, type: :string, description: "flow id", required: true]
    ],
    request_body: {"Flow to be updated", "application/json", FlowSchema.FlowRequest},
    responses: [
      ok: {"Ok", "application/json", FlowSchema.FlowWithCreator},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error},
      not_found: {"Not found", "application/json", Error}
    ]
  )

  @spec update(Plug.Conn.t(), map) :: Plug.Conn.t()
  def update(conn, %{"id" => id} = params) do
    current_user = conn.assigns[:current_user]

    with %Flow{} = flow <- Enterprise.get_flow(id, current_user),
         %Flow{} = flow <- Enterprise.update_flow(flow, params) do
      Typesense.update_document(flow)
      render(conn, "update.json", flow: flow)
    end
  end

  operation(:align_states,
    summary: "Update states",
    description: "Api to update order of states of a flow",
    parameters: [
      id: [in: :path, type: :string, description: "Flow id", required: true]
    ],
    request_body:
      {"Flow and states to be updated", "application/json", FlowSchema.AlignStateRequest},
    responses: [
      ok: {"Ok", "application/json", FlowSchema.FlowFull},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error},
      not_found: {"Not found", "application/json", Error}
    ]
  )

  def align_states(conn, %{"id" => id} = params) do
    current_user = conn.assigns.current_user

    with %Flow{} = flow <- Enterprise.show_flow(id, current_user),
         %Flow{} = flow <- Enterprise.align_states(flow, params) do
      render(conn, "show.json", %{flow: flow})
    end
  end

  operation(:delete,
    summary: "Flow delete",
    description: "API to delete a flow",
    parameters: [
      id: [in: :path, type: :string, description: "flow id", required: true]
    ],
    responses: [
      ok: {"Ok", "application/json", FlowSchema.FlowBase},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error},
      not_found: {"Not found", "application/json", Error}
    ]
  )

  @spec delete(Plug.Conn.t(), map) :: Plug.Conn.t()
  def delete(conn, %{"id" => id}) do
    current_user = conn.assigns[:current_user]

    with %Flow{} = flow <- Enterprise.get_flow(id, current_user),
         {:ok, %Flow{}} <- Enterprise.delete_flow(flow) do
      Typesense.delete_document(flow.id, "flow")
      render(conn, "flow.json", flow: flow)
    end
  end
end
