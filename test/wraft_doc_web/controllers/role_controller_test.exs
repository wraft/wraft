defmodule WraftDocWeb.Api.V1.RoleControllerTest do
  @moduledoc """
  Test module for role controller test
  """
  use WraftDocWeb.ConnCase
  @moduletag :controller
  alias WraftDoc.Account.Role
  alias WraftDoc.Repo
  import WraftDoc.Factory

  describe "create/2" do
    # TODO - Test update success case
    # test "create role with valid attrs", %{conn: conn} do
    #   count_before = Role |> Repo.all() |> length()
    #   conn = post(conn, Routes.v1_role_path(conn, :create, @valid_attrs))
    #   count_after = Role |> Repo.all() |> length()
    #   assert json_response(conn, 200)["name"] == @valid_attrs.name
    #   assert count_before + 1 == count_after
    # end

    # TODO - Test update invalid case
    # test "does not create role with invalid attrs", %{conn: conn} do
    #   count_before = Role |> Repo.all() |> length()

    #   conn = post(conn, Routes.v1_role_path(conn, :create, @invalid_attrs))
    #   count_after = Role |> Repo.all() |> length()

    #   assert json_response(conn, 422)["errors"]["name"] == ["can't be blank"]
    #   assert count_before == count_after
    # end
  end

  test "show all the role with the content type", %{conn: conn} do
    user = conn.assigns.current_user
    role = insert(:role, name: "Editor", organisation: List.first(user.owned_organisations))
    conn = get(conn, Routes.v1_role_path(conn, :show, role.id))
    assert json_response(conn, 200)["name"] == role.name
  end

  test "error not found for id does not exits", %{conn: conn} do
    conn = get(conn, Routes.v1_role_path(conn, :show, Ecto.UUID.autogenerate()))
    assert json_response(conn, 404) == "Not Found"
  end

  test "delete an existing role by id", %{conn: conn} do
    user = conn.assigns.current_user
    role = insert(:role, name: "new_role", organisation: List.first(user.owned_organisations))
    count_before = Role |> Repo.all() |> length()
    conn = delete(conn, Routes.v1_role_path(conn, :delete, role.id))
    count_after = Role |> Repo.all() |> length()

    assert json_response(conn, 200)["name"] == role.name
    assert count_before - 1 == count_after
  end

  describe "index/2" do
    test "index lists all roles in user's current organisation", %{conn: conn} do
      user = conn.assigns.current_user

      role_1 = insert(:role, name: "Role 1", organisation: List.first(user.owned_organisations))
      role_2 = insert(:role, name: "Role 2", organisation: List.first(user.owned_organisations))

      conn = get(conn, Routes.v1_role_path(conn, :index, %{}))

      roles_index_by_org =
        conn
        |> json_response(200)
        |> Enum.map(fn %{"name" => name} -> name end)
        |> List.to_string()

      assert roles_index_by_org =~ role_1.name
      assert roles_index_by_org =~ role_2.name
    end

    test "returns an empty list when there are no roles in user's organisation", %{conn: conn} do
      conn = get(conn, Routes.v1_role_path(conn, :index, %{"name" => "Does not exist"}))
      assert [] == json_response(conn, 200)
    end
  end

  describe "update/2" do
    # TODO - Test success response
    # TODO - Test failure response
    # TODO -> Role does not belong to the user's organisation
  end

  describe "assign_role/2" do
    # TODO - Test the success response
    # TODO - Test the failure response
    # 1 When the user doesn't belong to current user's current organisation
    # 2 Role doesn't belong to current user's current organisation
    # 3 Changeset errors when inserting a user_role
  end

  describe "unassign_role/2" do
    test "successfully unassigns a role from a user", %{conn: conn} do
      organisation = List.first(conn.assigns.current_user.owned_organisations)
      role = insert(:role, name: "editor", organisation: organisation)
      user = insert(:user)
      insert(:user_organisation, user: user, organisation: organisation)
      insert(:user_role, user: user, role: role)

      conn =
        delete(
          conn,
          Routes.v1_role_path(conn, :unassign_role, user.id, role.id)
        )

      assert json_response(conn, 200) == %{
               "info" => "Unassigned the given role from the user successfully.!"
             }
    end

    test "returns an error when the user_role does not belong to the current user's current organisation",
         %{conn: conn} do
      %{role_id: role_id, user_id: user_id} = insert(:user_role)

      conn = delete(conn, Routes.v1_role_path(conn, :unassign_role, user_id, role_id))

      assert json_response(conn, 404) == "Not Found"
    end
  end
end
