defmodule WraftDocWeb.Api.V1.LayoutControllerTest do
  @moduledoc """
  Test module for layout controller
  """
  use WraftDocWeb.ConnCase

  import WraftDoc.Factory
  alias WraftDoc.{Document.Layout, Repo}

  @valid_attrs %{
    name: "Official Letter",
    description: "An official letter",
    width: 40.0,
    height: 20.0,
    unit: "cm",
    slug: "Pandoc",
    slug_file: "/official_letter.zip",
    screenshot: "/official_letter.jpg",
    organisation_id: 12
  }

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

  test "create layouts on valid attrrs", %{conn: conn} do
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    count_before = Layout |> Repo.all() |> length()

    organisation = insert(:organisation)
    %{uuid: engine_uuid} = insert(:engine)

    params =
      Map.put(@valid_attrs, :organisation, organisation) |> Map.put(:engine_uuid, engine_uuid)

    conn =
      post(conn, Routes.v1_layout_path(conn, :create), params)
      |> doc(operation_id: "create_layout")

    assert count_before + 1 == Layout |> Repo.all() |> length()
    assert json_response(conn, 200)["name"] == @valid_attrs.name
  end

  test "does not create layouts on invalid attrs", %{conn: conn} do
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    count_before = Layout |> Repo.all() |> length()
    %{uuid: engine_uuid} = insert(:engine)
    params = Map.put(@invalid_attrs, :engine_uuid, engine_uuid)

    conn =
      post(conn, Routes.v1_layout_path(conn, :create, params))
      |> doc(operation_id: "create_layout")

    assert json_response(conn, 422)["errors"]["name"] == ["can't be blank"]
    assert count_before == Layout |> Repo.all() |> length()
  end

  test "update layouts on valid attributes", %{conn: conn} do
    layout = insert(:layout, creator: conn.assigns.current_user)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    engine = insert(:engine)
    params = Map.merge(@valid_attrs, %{engine_id: engine.id})

    count_before = Layout |> Repo.all() |> length()

    conn =
      put(conn, Routes.v1_layout_path(conn, :update, layout.uuid), params)
      |> doc(operation_id: "update_layout")

    assert json_response(conn, 200)["layout"]["name"] == @valid_attrs.name
    assert count_before == Layout |> Repo.all() |> length()
  end

  test "does't update layouts on invalid attrs", %{conn: conn} do
    layout = insert(:layout, creator: conn.assigns.current_user)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    conn =
      put(conn, Routes.v1_layout_path(conn, :update, layout.uuid, @invalid_attrs))
      |> doc(operation_id: "update_layout")

    assert json_response(conn, 422)["errors"]["engine_id"] == ["can't be blank"]
  end

  test "index lists assests by current user", %{conn: conn} do
    user = conn.assigns.current_user

    a1 = insert(:layout, creator: user, organisation: user.organisation)
    a2 = insert(:layout, creator: user, organisation: user.organisation)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    conn = get(conn, Routes.v1_layout_path(conn, :index))
    layouts_index = json_response(conn, 200)["layouts"]
    layouts = Enum.map(layouts_index, fn %{"name" => name} -> name end)
    assert List.to_string(layouts) =~ a1.name
    assert List.to_string(layouts) =~ a2.name
  end

  test "show renders layout details by id", %{conn: conn} do
    layout = insert(:layout, creator: conn.assigns.current_user)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    conn = get(conn, Routes.v1_layout_path(conn, :show, layout.uuid))

    assert json_response(conn, 200)["layout"]["name"] == layout.name
  end

  test "error not found for id does not exists", %{conn: conn} do
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    conn = get(conn, Routes.v1_layout_path(conn, :show, Ecto.UUID.generate()))
    assert json_response(conn, 404) == "Not Found"
  end

  test "delete layout by given id", %{conn: conn} do
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    layout = insert(:layout, creator: conn.assigns.current_user)
    count_before = Layout |> Repo.all() |> length()

    conn = delete(conn, Routes.v1_layout_path(conn, :delete, layout.uuid))
    assert count_before - 1 == Layout |> Repo.all() |> length()
    assert json_response(conn, 200)["name"] == layout.name
  end
end
