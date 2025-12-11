defmodule WraftDocWeb.Api.V1.RoleController do
  use WraftDocWeb, :controller
  use OpenApiSpex.ControllerSpecs

  plug WraftDocWeb.Plug.Authorized,
    create: "role:manage",
    show: "role:show",
    delete: "role:delete",
    index: "role:show",
    update: "role:manage",
    assign_role: "role:manage"

  alias WraftDoc.Account
  alias WraftDoc.Account.Role
  alias WraftDoc.Account.User
  alias WraftDoc.Account.UserOrganisation
  alias WraftDoc.Account.UserRole
  alias WraftDoc.Enterprise
  alias WraftDoc.Enterprise.Organisation
  alias WraftDoc.Notifications.Delivery
  alias WraftDocWeb.Schemas.Error
  alias WraftDocWeb.Schemas.Role, as: RoleSchema

  action_fallback(WraftDocWeb.FallbackController)

  tags(["Roles"])

  operation(:create,
    summary: "Create roles",
    description: "Create specified roles in organisation",
    request_body: {"Role to be created", "application/json", RoleSchema.RoleRequest},
    responses: [
      ok: {"Ok", "application/json", RoleSchema.Role},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error},
      bad_request: {"Bad Request", "application/json", Error}
    ]
  )

  def create(conn, params) do
    user = conn.assigns.current_user

    with %Role{} = role <- Account.create_role(user, params) do
      render(conn, "show.json", role: role)
    end
  end

  operation(:show,
    summary: "show all the content type under the role",
    description: "API to list all the content type under the role",
    parameters: [
      id: [in: :path, type: :string, description: "id", required: true]
    ],
    responses: [
      ok: {"Ok", "application/json", RoleSchema.Role},
      unauthorized: {"Unauthorized", "application/json", Error},
      not_found: {"Not Found", "application/json", Error}
    ]
  )

  def show(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user

    with %Role{} = role <- Account.show_role(current_user, id) do
      render(conn, "show.json", role: role)
    end
  end

  operation(:delete,
    summary: "Delete a role",
    description: "API to delete a role",
    parameters: [
      id: [in: :path, type: :string, description: "role id", required: true]
    ],
    responses: [
      ok: {"Ok", "application/json", RoleSchema.Role},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error},
      bad_request: {"Bad Request", "application/json", Error}
    ]
  )

  @spec delete(Plug.Conn.t(), map) :: Plug.Conn.t()
  def delete(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    with %Role{} = role <- Account.show_role(user, id),
         {:ok, %Role{}} <- Account.delete_role(role) do
      render(conn, "show.json", role: role)
    end
  end

  operation(:index,
    summary: "List of roles",
    description: "All roles in an organisation",
    parameters: [
      name: [in: :query, type: :string, description: "Role Name"],
      sort: [in: :query, type: :string, description: "Sort Keys => name, name_desc"]
    ],
    responses: [
      ok: {"Ok", "application/json", RoleSchema.ListOfRoles},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  def index(conn, params) do
    current_user = conn.assigns[:current_user]
    roles = Enterprise.roles_in_users_organisation(current_user, params)
    render(conn, "index.json", roles: roles)
  end

  operation(:update,
    summary: "Update role",
    description: "Update role name and permissions",
    parameters: [
      id: [in: :path, type: :string, description: "role id", required: true]
    ],
    request_body: {"Role to be updated", "application/json", RoleSchema.RoleRequest},
    responses: [
      ok: {"Ok", "application/json", RoleSchema.Role},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error},
      not_found: {"Not found", "application/json", Error}
    ]
  )

  @spec update(Plug.Conn.t(), map) :: Plug.Conn.t()
  def update(conn, %{"id" => uuid} = params) do
    current_user = conn.assigns[:current_user]

    with %Role{} = role <- Account.get_role(current_user, uuid),
         %Role{} = role <- Account.update_role(role, params) do
      render(conn, "show.json", role: role)
    end
  end

  operation(:assign_role,
    summary: "Assign Role",
    description: "Assign role to the given user",
    parameters: [
      user_id: [in: :path, type: :string, description: "user id", required: true],
      role_id: [in: :path, type: :string, description: "role id", required: true]
    ],
    responses: [
      ok: {"Ok", "application/json", RoleSchema.AssignRole},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error},
      not_found: {"Not found", "application/json", Error},
      bad_request: {"Bad Request", "application/json", Error}
    ]
  )

  @doc """
    Assign role to the given user
  """
  @spec assign_role(Plug.Conn.t(), map) :: Plug.Conn.t()
  def assign_role(conn, %{"user_id" => user_id, "role_id" => role_id} = _params) do
    current_user = conn.assigns[:current_user]

    with %UserOrganisation{} <- Enterprise.get_user_organisation(current_user, user_id),
         %Role{id: role_id, organisation: %Organisation{name: organisation_name}, name: role_name} =
           _role <-
           Account.get_role_with_organisation(current_user, role_id),
         {:ok, %UserRole{}} <- Account.create_user_role(user_id, role_id),
         %User{id: user_id} = user <- Account.get_user(user_id) do
      Task.start(fn ->
        user
        |> Map.put(:current_org_id, current_user.current_org_id)
        |> Delivery.dispatch("organisation.assign_role", %{
          role_name: role_name,
          assigned_by: current_user.name,
          organisation_name: organisation_name,
          channel: :user_notification,
          channel_id: user_id,
          metadata: %{user_id: user_id, type: "role", role_id: role_id, role_name: role_name}
        })
      end)

      render(conn, "assign_role.json")
    end
  end

  operation(:unassign_role,
    summary: "Unassign Role",
    description: "Unassign role to the given user",
    parameters: [
      user_id: [in: :path, type: :string, description: "user id", required: true],
      role_id: [in: :path, type: :string, description: "role id", required: true]
    ],
    responses: [
      ok: {"Ok", "application/json", RoleSchema.UnassignRole},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error},
      not_found: {"Not found", "application/json", Error}
    ]
  )

  @doc """
    Unassign role from the given user
  """
  @spec unassign_role(Plug.Conn.t(), map) :: Plug.Conn.t()
  def unassign_role(conn, %{"user_id" => user_id, "role_id" => role_id} = _params) do
    current_user = conn.assigns[:current_user]

    with %Role{id: role_id, name: role_name, organisation: %Organisation{name: organisation_name}} =
           _role <-
           Account.get_role_with_organisation(current_user, role_id),
         true <- Account.allowed_to_unassign_role?(current_user, user_id, role_name),
         %UserRole{} = user_role <- Account.get_user_role(current_user, user_id, role_id),
         {:ok, _} <- Account.delete_user_role(user_role),
         %User{id: user_id} = user <- Account.get_user(user_id) do
      Task.start(fn ->
        user
        |> Map.put(:current_org_id, current_user.current_org_id)
        |> Delivery.dispatch("organisation.unassign_role", %{
          role_name: role_name,
          organisation_name: organisation_name,
          unassigned_by: current_user.name,
          channel: :user_notification,
          channel_id: user_id,
          metadata: %{user_id: user_id, type: "role", role_id: role_id, role_name: role_name}
        })
      end)

      render(conn, "unassign_role.json")
    end
  end
end
