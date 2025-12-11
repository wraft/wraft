defmodule WraftDocWeb.Api.V1.ApprovalSystemController do
  use WraftDocWeb, :controller
  use OpenApiSpex.ControllerSpecs
  plug WraftDocWeb.Plug.AddActionLog

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.Enterprise
  alias WraftDoc.Enterprise.ApprovalSystem

  alias WraftDocWeb.Schemas.ApprovalSystem, as: ApprovalSystemSchema
  alias WraftDocWeb.Schemas.Error

  tags(["Approval System"])

  operation(:create,
    summary: "Create approval_system",
    description: "Create approval_system API",
    request_body:
      {"ApprovalSystem to be created", "application/json",
       ApprovalSystemSchema.ApprovalSystemRequest},
    responses: [
      ok: {"Ok", "application/json", ApprovalSystemSchema.ApprovalSystem},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error},
      bad_request: {"Bad Request", "application/json", Error}
    ]
  )

  @spec create(Plug.Conn.t(), map) :: Plug.Conn.t()
  def create(conn, params) do
    current_user = conn.assigns.current_user

    with %ApprovalSystem{} = approval_system <-
           Enterprise.create_approval_system(current_user, params) do
      render(conn, "show.json", approval_system: approval_system)
    end
  end

  operation(:show,
    summary: "Show a approval_system",
    description: "API to show details of a approval_system",
    parameters: [
      id: [in: :path, type: :string, description: "approval_system id", required: true]
    ],
    responses: [
      ok: {"Ok", "application/json", ApprovalSystemSchema.ApprovalSystem},
      unauthorized: {"Unauthorized", "application/json", Error},
      bad_request: {"Bad Request", "application/json", Error}
    ]
  )

  @spec show(Plug.Conn.t(), map) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user

    with %ApprovalSystem{} = approval_system <- Enterprise.show_approval_system(id, current_user) do
      render(conn, "show.json", approval_system: approval_system)
    end
  end

  operation(:update,
    summary: "Update a approval_system",
    description: "API to update a approval_system",
    parameters: [
      id: [in: :path, type: :string, description: "approval_system id", required: true]
    ],
    request_body:
      {"ApprovalSystem to be updated", "application/json",
       ApprovalSystemSchema.ApprovalSystemRequest},
    responses: [
      ok: {"Ok", "application/json", ApprovalSystemSchema.ApprovalSystem},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error},
      bad_request: {"Bad Request", "application/json", Error}
    ]
  )

  @spec update(Plug.Conn.t(), map) :: Plug.Conn.t()
  def update(conn, %{"id" => id} = params) do
    current_user = conn.assigns.current_user

    with %ApprovalSystem{} = approval_system <-
           Enterprise.get_approval_system(id, current_user),
         %ApprovalSystem{} = approval_system <-
           Enterprise.update_approval_system(current_user, approval_system, params) do
      render(conn, "show.json", approval_system: approval_system)
    end
  end

  operation(:delete,
    summary: "Delete a approval_system",
    description: "API to delete a approval_system",
    parameters: [
      id: [in: :path, type: :string, description: "approval_system id", required: true]
    ],
    responses: [
      ok: {"Ok", "application/json", ApprovalSystemSchema.ApprovalSystem},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error},
      bad_request: {"Bad Request", "application/json", Error}
    ]
  )

  @spec delete(Plug.Conn.t(), map) :: Plug.Conn.t()
  def delete(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user

    with %ApprovalSystem{} = approval_system <-
           Enterprise.get_approval_system(id, current_user),
         %ApprovalSystem{} = approval_system <- Enterprise.delete_approval_system(approval_system) do
      render(conn, "show.json", approval_system: approval_system)
    end
  end

  operation(:index,
    summary: "Approval systems",
    description: "Api to list approval systems",
    parameters: [
      page: [in: :query, type: :string, description: "Page"]
    ],
    responses: [
      ok: {"Ok", "application/json", ApprovalSystemSchema.Approved},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error},
      bad_request: {"Bad Request", "application/json", Error}
    ]
  )

  def index(conn, params) do
    current_user = conn.assigns.current_user

    with %{
           entries: approval_systems,
           page_number: page_number,
           page_size: page_size,
           total_pages: total_pages,
           total_entries: total_entries
         } <- Enterprise.list_approval_systems(current_user, params) do
      render(conn, "index.json",
        approval_systems: approval_systems,
        page_number: page_number,
        page_size: page_size,
        total_pages: total_pages,
        total_entries: total_entries
      )
    end
  end
end
