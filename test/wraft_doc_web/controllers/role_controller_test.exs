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
    role = insert(:role, organisation: user.organisation)
    conn = get(conn, Routes.v1_role_path(conn, :show, role.id))
    assert json_response(conn, 200)["name"] == role.name
  end

  test "error not found for id does not exits", %{conn: conn} do
    conn = get(conn, Routes.v1_role_path(conn, :show, Ecto.UUID.autogenerate()))
    assert json_response(conn, 400)["errors"] == "The Role id does not exist..!"
  end

  test "delete an existing role by id", %{conn: conn} do
    user = conn.assigns.current_user
    role = insert(:role, organisation: user.organisation)
    count_before = Role |> Repo.all() |> length()
    conn = delete(conn, Routes.v1_role_path(conn, :delete, role.id))
    count_after = Role |> Repo.all() |> length()

    assert json_response(conn, 200)["name"] == role.name
    assert count_before - 1 == count_after
  end

  describe "index/2" do
    # TODO - Test success response
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
end
