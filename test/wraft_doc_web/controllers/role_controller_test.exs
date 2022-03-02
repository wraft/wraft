defmodule WraftDocWeb.Api.V1.RoleControllerTest do
  @moduledoc """
  Test module for role controller test
  """
  use WraftDocWeb.ConnCase
  @moduletag :controller
  alias WraftDoc.Account.Role
  alias WraftDoc.Repo
  import WraftDoc.Factory

  @valid_attrs %{name: "manager"}
  @invalid_attrs %{name: nil}

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

  test "create role with valid attrs", %{conn: conn} do
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    user = conn.assigns.current_user
    insert(:membership, organisation: user.organisation)
    count_before = Role |> Repo.all() |> length()
    conn = post(conn, Routes.v1_role_path(conn, :create, @valid_attrs))
    count_after = Role |> Repo.all() |> length()
    assert json_response(conn, 200)["name"] == @valid_attrs.name
    assert count_before + 1 == count_after
  end

  test "does not create role with invalid attrs", %{conn: conn} do
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    user = conn.assigns.current_user
    insert(:membership, organisation: user.organisation)

    count_before = Role |> Repo.all() |> length()

    conn = post(conn, Routes.v1_role_path(conn, :create, @invalid_attrs))
    count_after = Role |> Repo.all() |> length()

    assert json_response(conn, 422)["errors"]["name"] == ["can't be blank"]
    assert count_before == count_after
  end

  test "show all the role with the content type", %{conn: conn} do
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    user = conn.assigns.current_user
    role = insert(:role, organisation: user.organisation)
    insert(:membership, organisation: user.organisation)
    conn = get(conn, Routes.v1_role_path(conn, :show, role.id))
    assert json_response(conn, 200)["name"] == role.name
  end

  test "error not found for id does not exits", %{conn: conn} do
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    user = conn.assigns.current_user
    insert(:membership, organisation: user.organisation)
    conn = get(conn, Routes.v1_role_path(conn, :show, Ecto.UUID.autogenerate()))
    assert json_response(conn, 400)["errors"] == "The Role id does not exist..!"
  end

  test "delete an existing role by id", %{conn: conn} do
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    user = conn.assigns.current_user
    role = insert(:role, organisation: user.organisation)
    insert(:membership, organisation: user.organisation)
    count_before = Role |> Repo.all() |> length()
    conn = delete(conn, Routes.v1_role_path(conn, :delete, role.id))
    count_after = Role |> Repo.all() |> length()

    assert json_response(conn, 200)["name"] == role.name
    assert count_before - 1 == count_after
  end
end
