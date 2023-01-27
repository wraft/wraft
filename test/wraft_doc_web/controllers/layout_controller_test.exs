defmodule WraftDocWeb.Api.V1.LayoutControllerTest do
  @moduledoc """
  Test module for layout controller
  """
  use WraftDocWeb.ConnCase
  @moduletag :controller
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

  @invalid_attrs %{engine_id: nil}

  describe "create/2" do
    test "create layouts on valid attrrs", %{conn: conn} do
      user = conn.assigns[:current_user]

      count_before = Layout |> Repo.all() |> length()
      %{id: engine_id} = insert(:engine)
      a1 = insert(:asset, organisation: user.organisation)
      a2 = insert(:asset, organisation: user.organisation)

      params = Map.merge(@valid_attrs, %{engine_id: engine_id, assets: "#{a1.id},#{a2.id}"})

      conn =
        conn
        |> post(Routes.v1_layout_path(conn, :create), params)
        |> doc(operation_id: "create_layout")

      la_names =
        conn
        |> json_response(200)
        |> get_in(["assets"])
        |> Enum.map(fn x -> x["name"] end)
        |> List.to_string()

      assert count_before + 1 == Layout |> Repo.all() |> length()
      assert json_response(conn, 200)["name"] == @valid_attrs.name
      assert la_names =~ a1.name
      assert la_names =~ a2.name
    end

    test "does not create layouts on invalid attrs", %{conn: conn} do
      count_before = Layout |> Repo.all() |> length()
      %{id: engine_id} = insert(:engine)
      params = Map.put(@invalid_attrs, :engine_id, engine_id)

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

      layout = insert(:layout, creator: user, organisation: user.organisation)

      engine = insert(:engine)
      a1 = insert(:asset, organisation: user.organisation)
      a2 = insert(:asset, organisation: user.organisation)
      params = Map.merge(@valid_attrs, %{engine_id: engine.id, assets: "#{a1.id},#{a2.id}"})

      count_before = Layout |> Repo.all() |> length()

      conn =
        conn
        |> put(Routes.v1_layout_path(conn, :update, layout.id), params)
        |> doc(operation_id: "update_layout")

      la_names =
        conn
        |> json_response(200)
        |> get_in(["layout", "assets"])
        |> Enum.map(fn x -> x["name"] end)
        |> List.to_string()

      assert count_before == Layout |> Repo.all() |> length()
      assert json_response(conn, 200)["layout"]["name"] == @valid_attrs.name
      assert la_names =~ a1.name
      assert la_names =~ a2.name
    end

    test "does't update layouts on invalid attrs", %{conn: conn} do
      user = conn.assigns.current_user

      layout = insert(:layout, creator: user, organisation: user.organisation)

      conn =
        conn
        |> put(Routes.v1_layout_path(conn, :update, layout.id, @invalid_attrs))
        |> doc(operation_id: "update_layout")

      assert json_response(conn, 422)["errors"]["engine_id"] == ["can't be blank"]
    end
  end

  describe "index/2" do
    test "index lists assests by current user", %{conn: conn} do
      user = conn.assigns.current_user

      a1 = insert(:layout, creator: user, organisation: user.organisation)
      a2 = insert(:layout, creator: user, organisation: user.organisation)

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

      layout = insert(:layout, creator: user, organisation: user.organisation)
      layout_asset1 = insert(:layout_asset, layout: layout)
      layout_asset2 = insert(:layout_asset, layout: layout)

      conn = get(conn, Routes.v1_layout_path(conn, :show, layout.id))

      la_names =
        conn
        |> json_response(200)
        |> get_in(["layout", "assets"])
        |> Enum.map(fn x -> x["name"] end)
        |> List.to_string()

      assert json_response(conn, 200)["layout"]["name"] == layout.name
      assert la_names =~ layout_asset1.asset.name
      assert la_names =~ layout_asset2.asset.name
    end

    test "error not found for id does not exists", %{conn: conn} do
      conn = get(conn, Routes.v1_layout_path(conn, :show, Ecto.UUID.generate()))
      assert json_response(conn, 400)["errors"] == "The Layout id does not exist..!"
    end

    test "error not found for user from another organisation", %{conn: conn} do
      layout = insert(:layout)
      conn = get(conn, Routes.v1_layout_path(conn, :show, layout.id))
      assert json_response(conn, 400)["errors"] == "The Layout id does not exist..!"
    end
  end

  describe "delete/2" do
    test "delete layout by given id", %{conn: conn} do
      user = conn.assigns[:current_user]
      layout = insert(:layout, creator: user, organisation: user.organisation)
      count_before = Layout |> Repo.all() |> length()

      conn = delete(conn, Routes.v1_layout_path(conn, :delete, layout.id))
      assert count_before - 1 == Layout |> Repo.all() |> length()
      assert json_response(conn, 200)["name"] == layout.name
    end
  end
end
