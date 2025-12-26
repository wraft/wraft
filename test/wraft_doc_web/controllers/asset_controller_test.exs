defmodule WraftDocWeb.Api.V1.AssetControllerTest do
  @moduledoc """
  Test module for asset controller
  """
  use WraftDocWeb.ConnCase, async: false
  @moduletag :controller
  import WraftDoc.Factory
  alias WraftDoc.Assets.Asset
  alias WraftDoc.Repo

  @valid_attrs %{
    name: "letter head",
    type: "layout",
    organisation_id: 12,
    file: %Plug.Upload{
      filename: "invoice.pdf",
      content_type: "application/pdf",
      path: "test/helper/invoice.pdf"
    }
  }

  @invalid_attrs %{}

  describe "create/2" do
    test "create assets by valid attrs", %{conn: conn} do
      count_before = Asset |> Repo.all() |> length()

      conn =
        conn
        |> post(Routes.v1_asset_path(conn, :create), @valid_attrs)
        |> doc(operation_id: "create_asset")

      assert count_before + 1 == Asset |> Repo.all() |> length()
      assert json_response(conn, 200)["name"] == @valid_attrs.name
    end

    test "does not create assets by invalid attrs", %{conn: conn} do
      count_before = Asset |> Repo.all() |> length()

      conn =
        conn
        |> post(Routes.v1_asset_path(conn, :create, @invalid_attrs))
        |> doc(operation_id: "create_asset")

      assert json_response(conn, 422)["errors"]["name"] == ["can't be blank"]
      assert count_before == Asset |> Repo.all() |> length()
    end
  end

  describe "update/2" do
    test "update assets on valid attrs", %{conn: conn} do
      user = conn.assigns.current_user
      asset = insert(:asset, creator: user, organisation: List.first(user.owned_organisations))
      count_before = Asset |> Repo.all() |> length()

      conn =
        conn
        |> put(Routes.v1_asset_path(conn, :update, asset.id), @valid_attrs)
        |> doc(operation_id: "update_asset")

      assert json_response(conn, 200)["name"] == @valid_attrs.name
      assert count_before == Asset |> Repo.all() |> length()
    end

    test "does't update assets for invalid attrs", %{conn: conn} do
      user = conn.assigns.current_user
      asset = insert(:asset, creator: user, organisation: List.first(user.owned_organisations))

      conn =
        conn
        |> put(Routes.v1_asset_path(conn, :update, asset.id, @invalid_attrs))
        |> doc(operation_id: "update_asset")

      assert json_response(conn, 422)["errors"]["file"] == ["can't be blank"]
    end
  end

  describe "index/2" do
    test "index lists assests by current user", %{conn: conn} do
      user = conn.assigns.current_user
      [organisation] = user.owned_organisations

      a1 = insert(:asset, creator: user, organisation: organisation)
      a2 = insert(:asset, creator: user, organisation: organisation)

      conn = get(conn, Routes.v1_asset_path(conn, :index))
      assets_index = json_response(conn, 200)["assets"]
      assets = Enum.map(assets_index, fn %{"name" => name} -> name end)
      assert List.to_string(assets) =~ a1.name
      assert List.to_string(assets) =~ a2.name
    end
  end

  describe "show/2" do
    test "show renders asset details by id", %{conn: conn} do
      user = conn.assigns.current_user

      asset = insert(:asset, creator: user, organisation: List.first(user.owned_organisations))

      conn = get(conn, Routes.v1_asset_path(conn, :show, asset.id))

      assert json_response(conn, 200)["asset"]["name"] == asset.name
    end

    test "error not found for id does not exists", %{conn: conn} do
      conn = get(conn, Routes.v1_asset_path(conn, :show, Ecto.UUID.generate()))
      assert json_response(conn, 400)["errors"] == "The id does not exist..!"
    end
  end

  describe "delete/2" do
    test "delete asset by given id", %{conn: conn} do
      user = conn.assigns.current_user
      asset = insert(:asset, creator: user, organisation: List.first(user.owned_organisations))
      count_before = Asset |> Repo.all() |> length()

      conn = delete(conn, Routes.v1_asset_path(conn, :delete, asset.id))
      assert count_before - 1 == Asset |> Repo.all() |> length()
      assert json_response(conn, 200)["name"] == asset.name
    end

    test "error Not Found on user from diffrent organisation", %{conn: conn} do
      asset = insert(:asset)

      conn = get(conn, Routes.v1_asset_path(conn, :show, asset.id))

      assert json_response(conn, 400)["errors"] == "The id does not exist..!"
    end
  end
end
