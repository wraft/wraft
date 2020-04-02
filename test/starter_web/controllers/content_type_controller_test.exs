defmodule WraftDocWeb.ContentTypeControllerTest do
  @moduledoc """
  Test module for content type controller
  """
  use WraftDocWeb.ConnCase

  import WraftDoc.Factory
  alias WraftDoc.{Document.ContentType, Repo}

  @valid_attrs %{
    name: "Offer letter",
    description: "An offer letter",
    fields: %{
      name: "string",
      position: "string",
      joining_date: "date",
      approved_by: "string"
    },
    prefix: "OFFLET",
    color: "#ffffff"
  }

  @invalid_attrs %{name: "Offer letter", description: "An offer letter"}
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

  test "create content types by valid attrrs", %{conn: conn} do
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    count_before = ContentType |> Repo.all() |> length()
    %{uuid: flow_uuid} = insert(:flow)
    %{uuid: layout_uuid} = insert(:layout)

    params = Map.merge(@valid_attrs, %{flow_uuid: flow_uuid, layout_uuid: layout_uuid})

    conn =
      post(
        conn,
        Routes.v1_content_type_path(conn, :create, params)
      )
      |> doc(operation_id: "create_content_type")

    assert count_before + 1 == ContentType |> Repo.all() |> length()
    assert json_response(conn, 200)["name"] == @valid_attrs.name
  end

  test "does not create content types by invalid attrs", %{conn: conn} do
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    count_before = ContentType |> Repo.all() |> length()
    %{uuid: flow_uuid} = insert(:flow)
    %{uuid: layout_uuid} = insert(:layout)

    params = Map.merge(@invalid_attrs, %{flow_uuid: flow_uuid, layout_uuid: layout_uuid})

    conn =
      post(conn, Routes.v1_content_type_path(conn, :create, params))
      |> doc(operation_id: "create_content_type")

    assert json_response(conn, 422)["errors"]["fields"] == ["can't be blank"]
    assert count_before == ContentType |> Repo.all() |> length()
  end

  test "update content type on valid attributes", %{conn: conn} do
    content_type = insert(:content_type, creator: conn.assigns.current_user)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    count_before = ContentType |> Repo.all() |> length()

    %{id: flow_uuid} = insert(:flow)
    %{id: layout_uuid} = insert(:layout)

    params = Map.merge(@valid_attrs, %{flow_id: flow_uuid, layout_id: layout_uuid})

    conn =
      put(conn, Routes.v1_content_type_path(conn, :update, content_type.uuid, params))
      |> doc(operation_id: "update_content_type")

    assert json_response(conn, 200)["content_type"]["name"] == @valid_attrs.name
    assert count_before == ContentType |> Repo.all() |> length()
  end

  test "does't update content types for invalid attrs", %{conn: conn} do
    content_type = insert(:content_type, creator: conn.assigns.current_user)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    conn =
      put(conn, Routes.v1_content_type_path(conn, :update, content_type.uuid, @invalid_attrs))
      |> doc(operation_id: "update_content_type")

    assert json_response(conn, 422)["errors"]["flow_id"] == ["can't be blank"]
  end

  test "index lists content type by current user", %{conn: conn} do
    user = conn.assigns.current_user

    ct1 = insert(:content_type, creator: user, organisation: user.organisation)
    ct2 = insert(:content_type, creator: user, organisation: user.organisation)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    conn = get(conn, Routes.v1_content_type_path(conn, :index))
    ct_index = json_response(conn, 200)["content_types"]
    content_type = Enum.map(ct_index, fn %{"name" => name} -> name end)
    assert List.to_string(content_type) =~ ct1.name
    assert List.to_string(content_type) =~ ct2.name
  end

  test "show renders content type details by id", %{conn: conn} do
    content_type = insert(:content_type, creator: conn.assigns.current_user)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    conn = get(conn, Routes.v1_content_type_path(conn, :show, content_type.uuid))

    assert json_response(conn, 200)["content_type"]["name"] == content_type.name
  end

  test "error not found for id does not exists", %{conn: conn} do
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    conn = get(conn, Routes.v1_asset_path(conn, :show, Ecto.UUID.generate()))
    assert json_response(conn, 404) == "Not Found"
  end

  test "delete content type by given id", %{conn: conn} do
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    content_type = insert(:content_type, creator: conn.assigns.current_user)
    count_before = ContentType |> Repo.all() |> length()

    conn = delete(conn, Routes.v1_content_type_path(conn, :delete, content_type.uuid))
    assert count_before - 1 == ContentType |> Repo.all() |> length()
    assert json_response(conn, 200)["name"] == content_type.name
  end
end