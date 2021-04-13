defmodule WraftDocWeb.Api.V1.ResourceControllerTest do
  @moduledoc """
  Test module for resource controller
  """
  use WraftDocWeb.ConnCase

  import WraftDoc.Factory
  alias WraftDoc.{Authorization.Resource, Repo}

  @valid_attrs %{
    category: "Flow",
    action: "create"
  }

  @invalid_attrs %{category: ""}
  setup %{conn: conn} do
    role = insert(:role, name: "super_admin")
    user = insert(:user)
    insert(:user_role, role: role, user: user)

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

  test "create resources by valid attrrs", %{conn: conn} do
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    count_before = Resource |> Repo.all() |> length()

    conn =
      conn
      |> post(Routes.v1_resource_path(conn, :create, @valid_attrs))
      |> doc(operation_id: "create_resource")

    assert count_before + 1 == Resource |> Repo.all() |> length()
    assert json_response(conn, 200)["category"] == @valid_attrs.category
  end

  test "does not create resources by invalid attrs", %{conn: conn} do
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    count_before = Resource |> Repo.all() |> length()

    conn =
      conn
      |> post(Routes.v1_resource_path(conn, :create, @invalid_attrs))
      |> doc(operation_id: "create_resource")

    assert json_response(conn, 422)["errors"]["category"] == ["can't be blank"]
    assert count_before == Resource |> Repo.all() |> length()
  end

  test "update resources on valid attributes", %{conn: conn} do
    resource = insert(:resource)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    count_before = Resource |> Repo.all() |> length()

    conn =
      conn
      |> put(Routes.v1_resource_path(conn, :update, resource.uuid, @valid_attrs))
      |> doc(operation_id: "update_resource")

    assert json_response(conn, 200)["category"] == @valid_attrs.category
    assert count_before == Resource |> Repo.all() |> length()
  end

  test "does't update resources for invalid attrs", %{conn: conn} do
    resource = insert(:resource)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    conn =
      conn
      |> put(Routes.v1_resource_path(conn, :update, resource.uuid, @invalid_attrs))
      |> doc(operation_id: "update_resource")

    assert json_response(conn, 422)["errors"]["category"] == ["can't be blank"]
  end

  test "index lists assests by current user", %{conn: conn} do
    user = conn.assigns.current_user

    a1 = insert(:resource)
    a2 = insert(:resource)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, user)

    conn = get(conn, Routes.v1_resource_path(conn, :index))
    resources_index = json_response(conn, 200)["resources"]
    resources = Enum.map(resources_index, fn %{"category" => category} -> category end)
    assert List.to_string(resources) =~ a1.category |> to_string()
    assert List.to_string(resources) =~ a2.category |> to_string()
  end

  test "show renders resource details by id", %{conn: conn} do
    resource = insert(:resource)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    conn = get(conn, Routes.v1_resource_path(conn, :show, resource.uuid))

    assert json_response(conn, 200)["category"] == resource.category |> to_string()
  end

  test "error not found for id does not exists", %{conn: conn} do
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    conn = get(conn, Routes.v1_resource_path(conn, :show, Ecto.UUID.generate()))
    assert json_response(conn, 404) == "Not Found"
  end

  test "delete resource by given id", %{conn: conn} do
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    resource = insert(:resource)
    count_before = Resource |> Repo.all() |> length()

    conn = delete(conn, Routes.v1_resource_path(conn, :delete, resource.uuid))
    assert count_before - 1 == Resource |> Repo.all() |> length()
    assert json_response(conn, 200)["category"] == resource.category |> to_string()
  end
end
