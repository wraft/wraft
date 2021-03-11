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

  describe "create/2" do
    test "create layouts on valid attrrs", %{conn: conn} do
      user = conn.assigns[:current_user]
      insert(:membership, organisation: user.organisation)

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, user)

      count_before = Layout |> Repo.all() |> length()
      %{uuid: engine_uuid} = insert(:engine)
      a1 = insert(:asset, organisation: user.organisation)
      a2 = insert(:asset, organisation: user.organisation)

      params =
        Map.merge(@valid_attrs, %{engine_uuid: engine_uuid, assets: "#{a1.uuid},#{a2.uuid}"})

      conn =
        conn
        |> post(Routes.v1_layout_path(conn, :create), params)
        |> doc(operation_id: "create_layout")

      la_names =
        conn
        |> json_response(200)["assets"]
        |> Enum.map(fn x -> x["name"] end)
        |> List.to_string()

      assert count_before + 1 == Layout |> Repo.all() |> length()
      assert json_response(conn, 200)["name"] == @valid_attrs.name
      assert la_names =~ a1.name
      assert la_names =~ a2.name
    end

    test "does not create layouts on invalid attrs", %{conn: conn} do
      user = conn.assigns[:current_user]
      insert(:membership, organisation: user.organisation)

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, user)

      count_before = Layout |> Repo.all() |> length()
      %{uuid: engine_uuid} = insert(:engine)
      params = Map.put(@invalid_attrs, :engine_uuid, engine_uuid)

      conn =
        conn
        |> post(Routes.v1_layout_path(conn, :create, params))
        |> doc(operation_id: "create_layout")

      assert json_response(conn, 422)["errors"]["name"] == ["can't be blank"]
      assert count_before == Layout |> Repo.all() |> length()
    end
  end

  describe "update/2" do
    test "update layouts on valid attributes", %{conn: conn} do
      user = conn.assigns.current_user
      insert(:membership, organisation: user.organisation)
      layout = insert(:layout, creator: user, organisation: user.organisation)

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, conn.assigns.current_user)

      engine = insert(:engine)
      a1 = insert(:asset, organisation: user.organisation)
      a2 = insert(:asset, organisation: user.organisation)
      params = Map.merge(@valid_attrs, %{engine_id: engine.id, assets: "#{a1.uuid},#{a2.uuid}"})

      count_before = Layout |> Repo.all() |> length()

      conn =
        conn
        |> put(Routes.v1_layout_path(conn, :update, layout.uuid), params)
        |> doc(operation_id: "update_layout")

      la_names =
        conn
        |> json_response(200)["layout"]["assets"]
        |> Enum.map(fn x -> x["name"] end)
        |> List.to_string()

      assert count_before == Layout |> Repo.all() |> length()
      assert json_response(conn, 200)["layout"]["name"] == @valid_attrs.name
      assert la_names =~ a1.name
      assert la_names =~ a2.name
    end

    test "does't update layouts on invalid attrs", %{conn: conn} do
      user = conn.assigns.current_user
      insert(:membership, organisation: user.organisation)
      layout = insert(:layout, creator: user, organisation: user.organisation)

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, conn.assigns.current_user)

      conn =
        conn
        |> put(Routes.v1_layout_path(conn, :update, layout.uuid, @invalid_attrs))
        |> doc(operation_id: "update_layout")

      assert json_response(conn, 422)["errors"]["engine_id"] == ["can't be blank"]
    end
  end

  describe "index/2" do
    test "index lists assests by current user", %{conn: conn} do
      user = conn.assigns.current_user
      insert(:membership, organisation: user.organisation)
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
  end

  describe "show/2" do
    test "show renders layout details by id", %{conn: conn} do
      user = conn.assigns.current_user
      insert(:membership, organisation: user.organisation)
      layout = insert(:layout, creator: user, organisation: user.organisation)
      layout_asset1 = insert(:layout_asset, layout: layout)
      layout_asset2 = insert(:layout_asset, layout: layout)

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, conn.assigns.current_user)

      conn = get(conn, Routes.v1_layout_path(conn, :show, layout.uuid))

      la_names =
        conn
        |> json_response(200)["layout"]["assets"]
        |> Enum.map(fn x -> x["name"] end)
        |> List.to_string()

      assert json_response(conn, 200)["layout"]["name"] == layout.name
      assert la_names =~ layout_asset1.asset.name
      assert la_names =~ layout_asset2.asset.name
    end

    test "error not found for id does not exists", %{conn: conn} do
      user = conn.assigns[:current_user]
      insert(:membership, organisation: user.organisation)

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, user)

      conn = get(conn, Routes.v1_layout_path(conn, :show, Ecto.UUID.generate()))
      assert json_response(conn, 404) == "Not Found"
    end

    test "error not found for user from another organisation", %{conn: conn} do
      current_user = conn.assigns[:current_user]
      insert(:membership, organisation: current_user.organisation)
      user = insert(:user)
      layout = insert(:layout, creator: user, organisation: user.organisation)

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, current_user)

      conn = get(conn, Routes.v1_layout_path(conn, :show, layout.uuid))

      assert json_response(conn, 404) == "Not Found"
    end
  end

  describe "delete/2" do
    test "delete layout by given id", %{conn: conn} do
      user = conn.assigns[:current_user]
      insert(:membership, organisation: user.organisation)

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
        |> assign(:current_user, user)

      user = conn.assigns.current_user
      layout = insert(:layout, creator: user, organisation: user.organisation)
      count_before = Layout |> Repo.all() |> length()

      conn = delete(conn, Routes.v1_layout_path(conn, :delete, layout.uuid))
      assert count_before - 1 == Layout |> Repo.all() |> length()
      assert json_response(conn, 200)["name"] == layout.name
    end
  end
end
