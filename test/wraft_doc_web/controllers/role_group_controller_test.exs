defmodule WraftDocWeb.Api.V1.RoleGroupControllerTest do
  use WraftDocWeb.ConnCase
  import WraftDoc.Factory

  alias WraftDoc.{Account.RoleGroup, Repo}

  @valid_attrs %{name: "Silver", description: "Silver category"}
  @invalid_attrs %{name: nil}

  setup %{conn: conn} do
    role = insert(:role, name: "admin")
    user = insert(:user)
    insert(:user_role, role: role, user: user)
    insert(:membership, organisation: user.organisation)

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

  describe "create/2" do
    test "with valid attrs ", %{conn: conn} do
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, conn.assigns.current_user)

      count_before = RoleGroup |> Repo.all() |> length()

      conn = post(conn, Routes.v1_role_group_path(conn, :create), @valid_attrs)

      assert json_response(conn, 200)["role_group"]["name"] == @valid_attrs.name
      assert count_before + 1 == RoleGroup |> Repo.all() |> length()
    end

    test "with invalid attrs", %{conn: conn} do
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, conn.assigns.current_user)

      count_before = RoleGroup |> Repo.all() |> length()

      conn = post(conn, Routes.v1_role_group_path(conn, :create), @invalid_attrs)
      assert json_response(conn, 422)["errors"]["name"] == ["can't be blank"]
      assert count_before == RoleGroup |> Repo.all() |> length()
    end
  end

  describe "show/2" do
    test "for existing keys", %{conn: conn} do
      user = conn.assigns.current_user

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, conn.assigns.current_user)

      role_group = insert(:role_group, organisation: user.organisation)
      conn = get(conn, Routes.v1_role_group_path(conn, :show, role_group.id))
      assert json_response(conn, 200)["role_group"]["name"] == role_group.name
    end

    test "for keys does not exist", %{conn: conn} do
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, conn.assigns.current_user)

      conn = get(conn, Routes.v1_role_group_path(conn, :show, Ecto.UUID.autogenerate()))
      assert json_response(conn, 404) == "Not Found"
    end
  end

  describe "update/2" do
    test "with valid attrs", %{conn: conn} do
      user = conn.assigns.current_user

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, conn.assigns.current_user)

      role_group = insert(:role_group, organisation: user.organisation)
      conn = put(conn, Routes.v1_role_group_path(conn, :update, role_group.id), @valid_attrs)
      assert json_response(conn, 200)["role_group"]["name"] == @valid_attrs.name
    end

    test "with invalid attrs", %{conn: conn} do
      user = conn.assigns.current_user

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, conn.assigns.current_user)

      role_group = insert(:role_group, organisation: user.organisation)
      conn = put(conn, Routes.v1_role_group_path(conn, :update, role_group.id), @invalid_attrs)
      assert json_response(conn, 422)["errors"]["name"] == ["can't be blank"]
    end
  end

  describe "delete/2" do
    test "deletes an existing entry", %{conn: conn} do
      user = conn.assigns.current_user

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, conn.assigns.current_user)

      role_group = insert(:role_group, organisation: user.organisation)
      count_before = RoleGroup |> Repo.all() |> length()
      conn = delete(conn, Routes.v1_role_group_path(conn, :delete, role_group.id))
      assert count_before - 1 == RoleGroup |> Repo.all() |> length()
      assert json_response(conn, 200)["name"] == role_group.name
    end
  end

  describe "index/2" do
    test "list all role groups", %{conn: conn} do
      user = conn.assigns.current_user

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, conn.assigns.current_user)

      rg1 = insert(:role_group, organisation: user.organisation)
      rg2 = insert(:role_group, organisation: user.organisation)
      conn = get(conn, Routes.v1_role_group_path(conn, :index))

      list = json_response(conn, 200)["role_groups"]

      assert list
             |> Enum.map(fn x -> x["name"] end)
             |> List.to_string() =~ rg1.name
    end
  end
end
