defmodule WraftDocWeb.Api.V1.ResourceControllerTest do
  @moduledoc """
  Test module for resource controller
  """
  use WraftDocWeb.ConnCase
  @moduletag :controller

  import WraftDoc.Factory
  alias WraftDoc.{Authorization.Resource, Repo}

  @valid_attrs %{
    category: "Flow",
    action: "create"
  }

  @invalid_attrs %{category: ""}
  setup %{conn: conn} do
    role = insert(:role, name: "super_admin")

    insert(:user_role, role: role, user: conn.assigns[:current_user])
    :ok
  end

  test "create resources by valid attrrs", %{conn: conn} do
    count_before = Resource |> Repo.all() |> length()

    conn =
      conn
      |> post(Routes.v1_resource_path(conn, :create, @valid_attrs))
      |> doc(operation_id: "create_resource")

    assert count_before + 1 == Resource |> Repo.all() |> length()
    assert json_response(conn, 200)["action"] == @valid_attrs.action
  end

  test "does not create resources by invalid attrs", %{conn: conn} do
    count_before = Resource |> Repo.all() |> length()

    conn = post(conn, Routes.v1_resource_path(conn, :create, @invalid_attrs))

    assert json_response(conn, 422)["errors"]["category"] == ["can't be blank"]
    assert count_before == Resource |> Repo.all() |> length()
  end

  test "update resources on valid attributes", %{conn: conn} do
    resource = insert(:resource)

    count_before = Resource |> Repo.all() |> length()

    conn =
      conn
      |> put(Routes.v1_resource_path(conn, :update, resource.id, @valid_attrs))
      |> doc(operation_id: "update_resource")

    assert json_response(conn, 200)["action"] == @valid_attrs.action
    assert count_before == Resource |> Repo.all() |> length()
  end

  test "does't update resources for invalid attrs", %{conn: conn} do
    resource = insert(:resource)

    conn =
      conn
      |> put(Routes.v1_resource_path(conn, :update, resource.id, @invalid_attrs))
      |> doc(operation_id: "update_resource")

    assert json_response(conn, 422)["errors"]["category"] == ["can't be blank"]
  end

  @label "flow"
  test "index lists assests by current user", %{conn: conn} do
    a1 = insert(:resource, label: @label)
    a2 = insert(:resource, label: @label)

    conn = get(conn, Routes.v1_resource_path(conn, :index))
    resources_index = List.first(json_response(conn, 200)["resources"])

    resources = Enum.map(resources_index["flow"], fn %{"action" => action} -> action end)
    assert List.to_string(resources) =~ to_string(a1.action)
    assert List.to_string(resources) =~ to_string(a2.action)
  end

  test "show renders resource details by id", %{conn: conn} do
    resource = insert(:resource)

    conn = get(conn, Routes.v1_resource_path(conn, :show, resource.id))

    assert json_response(conn, 200)["action"] == to_string(resource.action)
  end

  test "error not found for id does not exists", %{conn: conn} do
    conn = get(conn, Routes.v1_resource_path(conn, :show, Ecto.UUID.generate()))
    assert json_response(conn, 400)["errors"] == "The Resource id does not exist..!"
  end

  test "delete resource by given id", %{conn: conn} do
    resource = insert(:resource)
    count_before = Resource |> Repo.all() |> length()

    conn = delete(conn, Routes.v1_resource_path(conn, :delete, resource.id))
    assert count_before - 1 == Resource |> Repo.all() |> length()
    assert json_response(conn, 200)["action"] == to_string(resource.action)
  end
end
