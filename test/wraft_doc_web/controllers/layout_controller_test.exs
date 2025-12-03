defmodule WraftDocWeb.Api.V1.LayoutControllerTest do
  @moduledoc """
  Test module for layout controller
  """
  use WraftDocWeb.ConnCase
  @moduletag :controller
  import WraftDoc.Factory
  alias WraftDoc.{Layouts.Layout, Repo}

  @valid_attrs %{
    "name" => "Official Letter",
    "description" => "An official letter",
    "width" => 40.0,
    "height" => 20.0,
    "unit" => "cm",
    "slug" => "Pandoc"
  }
  describe "create/2" do
    test "create layouts on valid attrs", %{conn: conn} do
      user = conn.assigns[:current_user]
      [organisation] = user.owned_organisations

      count_before = Layout |> Repo.all() |> length()
      %{id: engine_id} = insert(:engine)

      asset = insert(:asset, organisation: organisation)

      params =
        Map.merge(@valid_attrs, %{
          "engine_id" => engine_id,
          "asset_id" => asset.id,
          "organisation_id" => organisation.id
        })

      conn =
        conn
        |> post(Routes.v1_layout_path(conn, :create), params)
        |> doc(operation_id: "create_layout")

      response = json_response(conn, 200)

      _asset_name =
        case get_in(response, ["asset", "name"]) do
          nil -> ""
          name -> name
        end

      assert count_before + 1 == Layout |> Repo.all() |> length()
      assert response["name"] == @valid_attrs["name"]

      assert response["id"]
    end

    test "does not create layouts on invalid attrs", %{conn: conn} do
      count_before = Layout |> Repo.all() |> length()
      %{id: engine_id} = insert(:engine)

      invalid_attrs = %{
        "name" => "",
        "engine_id" => engine_id,
        "organisation_id" =>
          conn.assigns.current_user.owned_organisations |> List.first() |> Map.get(:id)
      }

      conn =
        conn
        |> post(Routes.v1_layout_path(conn, :create), invalid_attrs)
        |> doc(operation_id: "create_layout")

      assert json_response(conn, 422)["errors"]["name"] == ["can't be blank"]
      assert count_before == Layout |> Repo.all() |> length()
    end

    test "return error if layout with same name exists", %{conn: conn} do
      user = conn.assigns[:current_user]
      [organisation] = user.owned_organisations

      insert(:layout, name: "Official Letter", creator: user, organisation: organisation)

      %{id: engine_id} = insert(:engine)
      asset = insert(:asset, organisation: organisation)

      params =
        Map.merge(@valid_attrs, %{
          "engine_id" => engine_id,
          "asset_id" => asset.id,
          "organisation_id" => organisation.id
        })

      conn =
        conn
        |> post(Routes.v1_layout_path(conn, :create), params)
        |> doc(operation_id: "create_layout")

      assert json_response(conn, 422)["errors"]["name"] == [
               "Layout with the same name exists. Use another name.!"
             ]
    end
  end

  describe "update/2" do
    test "update layouts on valid attributes", %{conn: conn} do
      user = conn.assigns.current_user
      [organisation] = user.owned_organisations
      layout = insert(:layout, creator: user, organisation: organisation)

      engine = insert(:engine)
      asset = insert(:asset, organisation: organisation)

      params =
        Map.merge(@valid_attrs, %{
          "engine_id" => engine.id,
          "asset_id" => asset.id
        })

      count_before = Layout |> Repo.all() |> length()

      conn =
        conn
        |> put(Routes.v1_layout_path(conn, :update, layout.id), params)
        |> doc(operation_id: "update_layout")

      response = json_response(conn, 200)
      layout_response = response["layout"]

      assert count_before == Layout |> Repo.all() |> length()
      assert layout_response["name"] == @valid_attrs["name"]
      assert layout_response["description"] == @valid_attrs["description"]
    end

    test "does't update layouts on invalid attrs", %{conn: conn} do
      user = conn.assigns.current_user
      layout = insert(:layout, creator: user, organisation: List.first(user.owned_organisations))

      invalid_attrs = %{
        "name" => "",
        "engine_id" => insert(:engine).id
      }

      conn =
        conn
        |> put(Routes.v1_layout_path(conn, :update, layout.id), invalid_attrs)
        |> doc(operation_id: "update_layout")

      assert json_response(conn, 422)["errors"]["name"] == ["can't be blank"]
    end

    test "return error if the layout with the same name exist", %{conn: conn} do
      user = conn.assigns.current_user
      [organisation] = user.owned_organisations
      layout = insert(:layout, creator: user, organisation: organisation)
      insert(:layout, name: "Official Letter", creator: user, organisation: organisation)

      engine = insert(:engine)

      conn =
        conn
        |> put(Routes.v1_layout_path(conn, :update, layout.id), %{
          "name" => "Official Letter",
          "slug" => "pletter",
          "engine_id" => engine.id
        })
        |> doc(operation_id: "update_layout")

      assert json_response(conn, 422)["errors"]["name"] == [
               "Layout with the same name exists. Use another name.!"
             ]
    end
  end

  describe "index/2" do
    test "index lists assests by current user", %{conn: conn} do
      user = conn.assigns.current_user
      [organisation] = user.owned_organisations
      a1 = insert(:layout, creator: user, organisation: organisation)
      a2 = insert(:layout, creator: user, organisation: organisation)

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
      layout = insert(:layout, creator: user, organisation: List.first(user.owned_organisations))

      conn = get(conn, Routes.v1_layout_path(conn, :show, layout.id))

      response = json_response(conn, 200)
      layout_response = response["layout"]

      assert layout_response["name"] == layout.name
      assert layout_response["id"] == layout.id
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
      layout = insert(:layout, creator: user, organisation: List.first(user.owned_organisations))
      count_before = Layout |> Repo.all() |> length()

      conn = delete(conn, Routes.v1_layout_path(conn, :delete, layout.id))
      assert count_before - 1 == Layout |> Repo.all() |> length()
      assert json_response(conn, 200)["name"] == layout.name
    end
  end
end
