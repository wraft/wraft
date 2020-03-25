defmodule WraftDocWeb.PermissionControllerTest do
  @moduledoc """
  Test module for permission controller
  """
  use WraftDocWeb.ConnCase

  import WraftDoc.Factory
  alias WraftDoc.{Authorization.Permission, Repo}

  @valid_attrs %{}
  @invalid_attrs %{}
  setup %{conn: conn} do
    user = insert(:user)

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
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    count_before = Permission |> Repo.all() |> length()

    conn =
      post(conn, Routes.v1_permission_path(conn, :create, @valid_attrs))
      |> doc(operation_id: "create_permission")

    assert count_before + 1 == Permission |> Repo.all() |> length()
    assert json_response(conn, 200)["role"] == @valid_attrs.role
  end

  test "does not create permissions by invalid attrs", %{conn: conn} do
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    count_before = Permission |> Repo.all() |> length()

    conn =
      post(conn, Routes.v1_permission_path(conn, :create, @invalid_attrs))
      |> doc(operation_id: "create_permission")

    assert json_response(conn, 422)["errors"]["role"] == ["can't be blank"]
    assert count_before == Permission |> Repo.all() |> length()
  end

  test "index lists assests by current user", %{conn: conn} do
    user = conn.assigns.current_user

    a1 = insert(:permission, creator: user, organisation: user.organisation)
    a2 = insert(:permission, creator: user, organisation: user.organisation)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    conn = get(conn, Routes.v1_permission_path(conn, :index))
    permissions_index = json_response(conn, 200)["permissions"]
    permissions = Enum.map(permissions_index, fn %{"role" => role} -> role end)
    assert List.to_string(permissions) =~ a1.role
    assert List.to_string(permissions) =~ a2.role
  end

  test "delete permission by given id", %{conn: conn} do
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    permission = insert(:permission, creator: conn.assigns.current_user)
    count_before = Permission |> Repo.all() |> length()

    conn = delete(conn, Routes.v1_permission_path(conn, :delete, permission.uuid))
    assert count_before - 1 == Permission |> Repo.all() |> length()
    assert json_response(conn, 200)["role"] == permission.role
  end
end
