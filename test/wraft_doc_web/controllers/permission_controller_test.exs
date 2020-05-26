defmodule WraftDocWeb.Api.V1.PermissionControllerTest do
  @moduledoc """
  Test module for permission controller
  """
  use WraftDocWeb.ConnCase

  import WraftDoc.Factory
  alias WraftDoc.{Authorization.Permission, Repo}

  @valid_attrs %{}
  @invalid_attrs %{}
  setup %{conn: conn} do
    role = insert(:role, name: "admin")
    user = insert(:user, role: role)

    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> post(
        Routes.v1_user_path(conn, :signin, %{
          email: user.email,
          password: user.password
        })
      )

    conn = assign(conn, :current_user, user)

    {:ok, %{conn: conn}}
  end

  test "create permissions by valid attrrs", %{conn: conn} do
    role = insert(:role)
    resource = insert(:resource)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    count_before = Permission |> Repo.all() |> length()
    params = @valid_attrs |> Map.merge(%{role_uuid: role.uuid, resource_uuid: resource.uuid})

    conn =
      post(conn, Routes.v1_permission_path(conn, :create, params))
      |> doc(operation_id: "create_permission")

    assert count_before + 1 == Permission |> Repo.all() |> length()
    assert json_response(conn, 200)["#{resource.category}_#{resource.action}"] == [role.name]
  end

  test "does not create permissions by invalid attrs", %{conn: conn} do
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    count_before = Permission |> Repo.all() |> length()

    params =
      @invalid_attrs
      |> Map.merge(%{role_uuid: Ecto.UUID.generate(), resource_uuid: Ecto.UUID.generate()})

    conn =
      post(conn, Routes.v1_permission_path(conn, :create, params))
      |> doc(operation_id: "create_permission")

    # assert json_response(conn, 422)["errors"]["role"] == ["can't be blank"]
    assert json_response(conn, 404) == "Not Found"
    assert count_before == Permission |> Repo.all() |> length()
  end

  test "index lists permissions by current user", %{conn: conn} do
    a1 = insert(:permission)
    a2 = insert(:permission)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    conn = get(conn, Routes.v1_permission_path(conn, :index))

    permissions =
      json_response(conn, 200)["permissions"]
      |> Enum.map(fn x -> Map.keys(x) end)
      |> List.flatten()

    assert List.to_string(permissions) =~ a1.resource.category <> "_" <> a1.resource.action
    assert List.to_string(permissions) =~ a2.resource.category <> "_" <> a2.resource.action
  end

  test "delete permission by given id", %{conn: conn} do
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    permission = insert(:permission)
    count_before = Permission |> Repo.all() |> length()

    conn = delete(conn, Routes.v1_permission_path(conn, :delete, permission.uuid))
    assert count_before - 1 == Permission |> Repo.all() |> length()
    assert json_response(conn, 200)["role_id"] == permission.role.id
  end
end