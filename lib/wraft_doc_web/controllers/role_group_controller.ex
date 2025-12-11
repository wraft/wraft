defmodule WraftDocWeb.Api.V1.RoleGroupController do
  use WraftDocWeb, :controller
  use OpenApiSpex.ControllerSpecs

  plug WraftDocWeb.Plug.AddActionLog

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.Account
  alias WraftDoc.Account.RoleGroup
  alias WraftDocWeb.Schemas.Error
  alias WraftDocWeb.Schemas.RoleGroup, as: RoleGroupSchema

  tags(["role_groups"])

  operation(:create,
    summary: "/create a role group",
    description: "/creates a role group",
    request_body: {"Role group to create", "application/json", RoleGroupSchema.RoleGroupRequest},
    responses: [
      ok: {"Updated", "application/json", RoleGroupSchema.RoleGroup},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  def create(conn, params) do
    with %RoleGroup{} = role_group <- Account.create_role_group(conn.assigns.current_user, params) do
      render(conn, "show.json", role_group: role_group)
    end
  end

  operation(:show,
    summary: "get a role group",
    parameters: [
      id: [in: :path, type: :string, description: "Role group id", required: true]
    ],
    responses: [
      ok: {"Created", "application/json", RoleGroupSchema.RoleGroup},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  def show(conn, %{"id" => id}) do
    with %RoleGroup{} = role_group <- Account.show_role_group(conn.assigns.current_user, id) do
      render(conn, "show.json", role_group: role_group)
    end
  end

  operation(:update,
    summary: "/update a role group",
    description: "/updates a role group",
    parameters: [
      id: [in: :path, type: :string, description: "Role group id", required: true]
    ],
    request_body: {"Role group to update", "application/json", RoleGroupSchema.RoleGroupRequest},
    responses: [
      ok: {"Updated", "application/json", RoleGroupSchema.RoleGroup},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  def update(conn, %{"id" => id} = params) do
    with %RoleGroup{} = role_group <- Account.get_role_group(conn.assigns.current_user, id),
         %RoleGroup{} = role_group <- Account.update_role_group(role_group, params) do
      render(conn, "show.json", role_group: role_group)
    end
  end

  operation(:delete,
    summary: "delete a role group",
    description: "Delete a role group",
    parameters: [
      id: [in: :path, type: :string, description: "Role group id", required: true]
    ],
    responses: [
      no_content: {"Deleted", "application/json", RoleGroupSchema.RoleGroup},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  def delete(conn, %{"id" => id}) do
    with %RoleGroup{} = role_group <- Account.get_role_group(conn.assigns.current_user, id),
         {:ok, role_group} <- Account.delete_role_group(role_group) do
      render(conn, "role_group.json", role_group: role_group)
    end
  end

  operation(:index,
    summary: "list role groups",
    description: "api to list all role groups",
    responses: [
      no_content: {"Deleted", "application/json", RoleGroupSchema.RoleGroupIndex},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  def index(conn, _params) do
    role_groups = Account.list_role_groups(conn.assigns.current_user)
    render(conn, "index.json", role_groups: role_groups)
  end
end
