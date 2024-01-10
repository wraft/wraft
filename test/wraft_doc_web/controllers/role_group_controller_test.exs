defmodule WraftDocWeb.Api.V1.RoleGroupControllerTest do
  use WraftDocWeb.ConnCase
  import WraftDoc.Factory

  alias WraftDoc.Account.RoleGroup
  alias WraftDoc.Repo

  @valid_attrs %{name: "Silver", description: "Silver category"}
  @invalid_attrs %{name: nil}

  describe "create/2" do
    test "with valid attrs ", %{conn: conn} do
      user = conn.assigns[:current_user]
      role = insert(:role, name: "admin", organisation: List.first(user.owned_organisations))
      valid_attrs = Map.put(@valid_attrs, :group_roles, [%{role_id: role.id}])

      conn = post(conn, Routes.v1_role_group_path(conn, :create), valid_attrs)

      assert json_response(conn, 200)["role_group"]["name"] == @valid_attrs.name
    end

    test "with invalid attrs", %{conn: conn} do
      conn = post(conn, Routes.v1_role_group_path(conn, :create), @invalid_attrs)
      assert json_response(conn, 422)["errors"]["name"] == ["can't be blank"]
    end
  end

  describe "show/2" do
    test "for existing keys", %{conn: conn} do
      user = conn.assigns[:current_user]
      role_group = insert(:role_group, organisation: List.first(user.owned_organisations))

      conn = get(conn, Routes.v1_role_group_path(conn, :show, role_group.id))
      assert json_response(conn, 200)["role_group"]["name"] == role_group.name
    end

    test "for keys does not exist", %{conn: conn} do
      conn = get(conn, Routes.v1_role_group_path(conn, :show, Ecto.UUID.autogenerate()))
      assert json_response(conn, 404) == "Not Found"
    end
  end

  describe "update/2" do
    test "with valid attrs", %{conn: conn} do
      user = conn.assigns.current_user
      role_group = insert(:role_group, organisation: List.first(user.owned_organisations))

      conn = put(conn, Routes.v1_role_group_path(conn, :update, role_group.id), @valid_attrs)
      assert json_response(conn, 200)["role_group"]["name"] == @valid_attrs.name
    end

    test "with invalid attrs", %{conn: conn} do
      user = conn.assigns.current_user
      role_group = insert(:role_group, organisation: List.first(user.owned_organisations))

      conn = put(conn, Routes.v1_role_group_path(conn, :update, role_group.id), @invalid_attrs)
      assert json_response(conn, 422)["errors"]["name"] == ["can't be blank"]
    end
  end

  describe "delete/2" do
    test "deletes an existing entry", %{conn: conn} do
      user = conn.assigns.current_user
      role_group = insert(:role_group, organisation: List.first(user.owned_organisations))
      count_before = RoleGroup |> Repo.all() |> length()

      conn = delete(conn, Routes.v1_role_group_path(conn, :delete, role_group.id))

      assert count_before - 1 == RoleGroup |> Repo.all() |> length()
      assert json_response(conn, 200)["name"] == role_group.name
    end
  end

  describe "index/2" do
    test "list all role groups", %{conn: conn} do
      user = conn.assigns.current_user
      rg1 = insert(:role_group, organisation: List.first(user.owned_organisations))

      conn = get(conn, Routes.v1_role_group_path(conn, :index))

      data = json_response(conn, 200)

      rg_name =
        data["role_groups"]
        |> Enum.map(fn x -> x["name"] end)
        |> List.to_string()

      assert ^rg_name = rg1.name
    end
  end
end
