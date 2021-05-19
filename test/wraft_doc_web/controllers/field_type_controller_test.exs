defmodule WraftDocWeb.Api.V1.FieldTypeControllerTest do
  @moduledoc """
  Test module for field type controller.
  """
  use WraftDocWeb.ConnCase
  import WraftDoc.Factory
  alias WraftDoc.{Document.FieldType, Repo}

  @valid_attrs %{name: "String", description: "A test field"}

  @invalid_attrs %{name: "", description: ""}
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

  test "create field type by valid attrrs", %{conn: conn} do
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    count_before = FieldType |> Repo.all() |> length()

    conn = post(conn, Routes.v1_field_type_path(conn, :create, @valid_attrs))

    assert count_before + 1 == FieldType |> Repo.all() |> length()
    assert json_response(conn, 200)["name"] == @valid_attrs.name
  end

  test "does not create field type by invalid attrs", %{conn: conn} do
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    count_before = FieldType |> Repo.all() |> length()

    conn = post(conn, Routes.v1_field_type_path(conn, :create, @invalid_attrs))

    assert json_response(conn, 422)["errors"]["name"] == ["can't be blank"]
    assert count_before == FieldType |> Repo.all() |> length()
  end

  test "update field type on valid attrs", %{conn: conn} do
    user = conn.assigns.current_user
    field_type = insert(:field_type, creator: user)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    count_before = FieldType |> Repo.all() |> length()

    conn = put(conn, Routes.v1_field_type_path(conn, :update, field_type.id), @valid_attrs)

    assert json_response(conn, 200)["name"] == @valid_attrs.name
    assert count_before == FieldType |> Repo.all() |> length()
  end

  test "does't update field type for invalid attrs", %{conn: conn} do
    user = conn.assigns.current_user

    field_type = insert(:field_type, creator: user)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    conn = put(conn, Routes.v1_field_type_path(conn, :update, field_type.id), @invalid_attrs)
    assert json_response(conn, 422)["errors"]["name"] == ["can't be blank"]
  end

  test "index lists field types", %{conn: conn} do
    ft1 = insert(:field_type)
    ft2 = insert(:field_type)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    conn = get(conn, Routes.v1_field_type_path(conn, :index))

    ft_index = json_response(conn, 200)["field_types"]
    fts = Enum.map(ft_index, fn %{"name" => name} -> name end)
    assert List.to_string(fts) =~ ft1.name
    assert List.to_string(fts) =~ ft2.name
  end

  test "show renders field type details by id", %{conn: conn} do
    user = conn.assigns.current_user
    field_type = insert(:field_type, creator: user)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    conn = get(conn, Routes.v1_field_type_path(conn, :show, field_type.id))

    assert json_response(conn, 200)["name"] == field_type.name
  end

  test "error not found for id does not exists", %{conn: conn} do
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    conn = get(conn, Routes.v1_field_type_path(conn, :show, Ecto.UUID.generate()))
    assert json_response(conn, 400)["errors"] == "The FieldType id does not exist..!"
  end

  test "delete field type by given id", %{conn: conn} do
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    user = conn.assigns.current_user
    field_type = insert(:field_type, creator: user)
    count_before = FieldType |> Repo.all() |> length()

    conn = delete(conn, Routes.v1_field_type_path(conn, :delete, field_type.id))
    assert count_before - 1 == FieldType |> Repo.all() |> length()
    assert json_response(conn, 200)["name"] == field_type.name
  end

  test "error not found on user from another organisation", %{conn: conn} do
    user = insert(:user)
    field_type = insert(:field_type, creator: user)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    conn = get(conn, Routes.v1_field_type_path(conn, :show, field_type.id))

    assert json_response(conn, 400)["errors"] == "The FieldType id does not exist..!"
  end
end
