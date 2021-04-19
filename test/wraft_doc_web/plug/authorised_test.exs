defmodule WraftDocWeb.Plug.AuthorizedTest do
  use WraftDocWeb.ConnCase
  import WraftDoc.Factory
  alias WraftDoc.Repo
  alias WraftDocWeb.Plug.Authorized

  test "user is authorised to continue if the user has permission in resource" do
    user = insert(:user)
    role = insert(:role, name: "hr_manager")
    insert(:user_role, user: user, role: role)
    user = Repo.preload(user, :roles)
    role_names = Enum.map(user.roles, fn x -> x.name end)
    user = Map.put(user, :role_names, role_names)
    resource = insert(:resource, category: WraftDocWeb.Api.V1.LayoutController, action: :create)
    insert(:permission, resource: resource, role: role)

    conn = assign(build_conn(), :current_user, user)

    conn =
      merge_private(conn, phoenix_controller: resource.category, phoenix_action: resource.action)

    returned_conn = Authorized.call(conn, %{})

    assert returned_conn == conn
    assert returned_conn.status != 400
  end

  test "rejected if the role does't have the permission" do
    user = insert(:user)
    role = insert(:role, name: "hr_manager")
    insert(:user_role, user: user, role: role)
    user = Repo.preload(user, :roles)
    role_names = Enum.map(user.roles, fn x -> x.name end)
    user = Map.put(user, :role_names, role_names)
    resource = insert(:resource, category: WraftDocWeb.Api.V1.LayoutController, action: :create)

    conn = assign(build_conn(), :current_user, user)

    conn =
      merge_private(conn, phoenix_controller: resource.category, phoenix_action: resource.action)

    returned_conn = Authorized.call(conn, %{})

    assert returned_conn != conn
    assert returned_conn.status == 400
  end

  test " user is autherized to continue if super_admin" do
    user = insert(:user)
    role = insert(:role, name: "super_admin")
    insert(:user_role, user: user, role: role)
    user = Repo.preload(user, :roles)
    role_names = Enum.map(user.roles, fn x -> x.name end)
    user = Map.put(user, :role_names, role_names)
    conn = assign(build_conn(), :current_user, user)
    resource = insert(:resource, category: WraftDocWeb.Api.V1.LayoutController, action: :create)

    conn =
      merge_private(conn, phoenix_controller: resource.category, phoenix_action: resource.action)

    returned_conn = Authorized.call(conn, %{})

    assert returned_conn == conn
    assert returned_conn.status != 400
  end

  test " authorize if the action is not in resource" do
    user = insert(:user)
    role = insert(:role, name: "user")
    insert(:user_role, user: user, role: role)
    user = Repo.preload(user, :roles)
    role_names = Enum.map(user.roles, fn x -> x.name end)
    user = Map.put(user, :role_names, role_names)
    conn = assign(build_conn(), :current_user, user)

    conn =
      merge_private(conn,
        phoenix_controller: WraftDocWeb.Api.V1.LayoutController,
        phoenix_action: :action
      )

    returned_conn = Authorized.call(conn, %{})

    assert returned_conn == conn
    assert returned_conn.status != 400
  end
end
