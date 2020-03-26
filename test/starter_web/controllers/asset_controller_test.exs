defmodule WraftDocWeb.AssetControllerTest do
  @moduledoc """
  Test module for asset controller
  """
  use WraftDocWeb.ConnCase

  import WraftDoc.Factory
  alias WraftDoc.{Document.Asset, Repo}

  @valid_attrs %{name: "letter head", organisation_id: 12}

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

  test "create assets by valid attrrs", %{conn: conn} do
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    count_before = Asset |> Repo.all() |> length()

    conn =
      post(conn, Routes.v1_asset_path(conn, :create, @valid_attrs))
      |> doc(operation_id: "create_asset")

    assert count_before + 1 == Asset |> Repo.all() |> length()
    assert json_response(conn, 200)["name"] == @valid_attrs.name
  end

  test "does not create assets by invalid attrs", %{conn: conn} do
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    count_before = Asset |> Repo.all() |> length()

    conn =
      post(conn, Routes.v1_asset_path(conn, :create, @invalid_attrs))
      |> doc(operation_id: "create_asset")

    assert json_response(conn, 422)["errors"]["name"] == ["can't be blank"]
    assert count_before == Asset |> Repo.all() |> length()
  end

  test "update assets on valid attrs with Plug.Upload", %{conn: conn} do
    asset = insert(:asset, creator: conn.assigns.current_user)
    content_type = insert(:content_type)
    filename = Plug.Upload.random_file!("test")
    uploader = %Plug.Upload{content_type: content_type, filename: filename, path: filename}
    params = Map.put(@valid_attrs, :file, uploader)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    count_before = Asset |> Repo.all() |> length()

    conn =
      put(conn, Routes.v1_asset_path(conn, :update, asset.uuid), params)
      |> doc(operation_id: "update_asset")

    assert json_response(conn, 200)["name"] == @valid_attrs.name
    assert count_before == Asset |> Repo.all() |> length()
  end

  test "does't update assets for invalid attrs", %{conn: conn} do
    asset = insert(:asset, creator: conn.assigns.current_user)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    conn =
      put(conn, Routes.v1_asset_path(conn, :update, asset.uuid, @invalid_attrs))
      |> doc(operation_id: "update_asset")

    assert json_response(conn, 422)["errors"]["file"] == ["can't be blank"]
  end

  test "index lists assests by current user", %{conn: conn} do
    user = conn.assigns.current_user

    a1 = insert(:asset, creator: user, organisation: user.organisation)
    a2 = insert(:asset, creator: user, organisation: user.organisation)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    conn = get(conn, Routes.v1_asset_path(conn, :index))
    assets_index = json_response(conn, 200)["assets"]
    assets = Enum.map(assets_index, fn %{"name" => name} -> name end)
    assert List.to_string(assets) =~ a1.name
    assert List.to_string(assets) =~ a2.name
  end

  test "show renders asset details by id", %{conn: conn} do
    asset = insert(:asset, creator: conn.assigns.current_user)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    conn = get(conn, Routes.v1_asset_path(conn, :show, asset.uuid))

    assert json_response(conn, 200)["asset"]["name"] == asset.name
  end

  test "error not found for id does not exists", %{conn: conn} do
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    conn = get(conn, Routes.v1_asset_path(conn, :show, Ecto.UUID.generate()))
    assert json_response(conn, 404) == "Not Found"
  end

  test "delete asset by given id", %{conn: conn} do
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    asset = insert(:asset, creator: conn.assigns.current_user)
    count_before = Asset |> Repo.all() |> length()

    conn = delete(conn, Routes.v1_asset_path(conn, :delete, asset.uuid))
    assert count_before - 1 == Asset |> Repo.all() |> length()
    assert json_response(conn, 200)["name"] == asset.name
  end
end
