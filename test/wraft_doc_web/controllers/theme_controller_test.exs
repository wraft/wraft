defmodule WraftDocWeb.Api.V1.ThemeControllerTest do
  @moduledoc """
  Test module for theme controller
  """
  use WraftDocWeb.ConnCase
  @moduletag :controller

  import WraftDoc.Factory
  import Mox
  alias WraftDoc.Document.Theme
  alias WraftDoc.Repo

  @valid_attrs %{
    name: "Official Letter Theme",
    font: "Malery",
    typescale: %{h1: "10", p: "6", h2: "8"},
    organisation_id: 12
  }

  @invalid_attrs %{body_color: "invalid hex format"}

  test "create themes by valid attrrs", %{conn: conn} do
    user = conn.assigns.current_user
    asset1 = insert(:asset, organisation: List.first(user.owned_organisations))
    asset2 = insert(:asset, organisation: List.first(user.owned_organisations))

    count_before = Theme |> Repo.all() |> length()

    conn =
      conn
      |> post(
        Routes.v1_theme_path(
          conn,
          :create,
          Map.merge(@valid_attrs, %{"assets" => "#{asset1.id},#{asset2.id}"})
        )
      )
      |> doc(operation_id: "create_theme")

    assert count_before + 1 == Theme |> Repo.all() |> length()
    assert json_response(conn, 200)["name"] == @valid_attrs.name
    assert [asset1.id, asset2.id] == Enum.map(json_response(conn, 200)["assets"], & &1["id"])
  end

  test "does not create themes by invalid attrs", %{conn: conn} do
    count_before = Theme |> Repo.all() |> length()

    conn =
      conn
      |> post(Routes.v1_theme_path(conn, :create, @invalid_attrs))
      |> doc(operation_id: "create_theme")

    assert json_response(conn, 422)["errors"]["name"] == ["can't be blank"]
    assert count_before == Theme |> Repo.all() |> length()
  end

  # TODO test failing need to fix it
  test "update themes on valid attrs ", %{conn: conn} do
    user = conn.assigns.current_user
    [organisation] = user.owned_organisations
    asset1 = insert(:asset, organisation: organisation)
    asset2 = insert(:asset, organisation: organisation)
    theme = insert(:theme, creator: user, organisation: organisation)
    content_type = insert(:content_type, organisation: organisation)
    filename = "test/helper/invoice.pdf"
    file = %Plug.Upload{content_type: content_type, filename: filename, path: filename}
    params = Map.merge(@valid_attrs, %{"file" => file, "organisation_id" => organisation.id})

    count_before = Theme |> Repo.all() |> length()

    conn =
      conn
      |> put(
        Routes.v1_theme_path(conn, :update, theme.id),
        Map.merge(params, %{"assets" => "#{asset1.id},#{asset2.id}"})
      )
      |> doc(operation_id: "update_theme")

    assert json_response(conn, 200)["name"] == @valid_attrs.name
    # assert [asset1.id, asset2.id] == Enum.map(json_response(conn, 200)["assets"], &(&1["id"]))
    assert count_before == Theme |> Repo.all() |> length()
  end

  test "does't update themes for invalid attrs", %{conn: conn} do
    user = conn.assigns.current_user
    theme = insert(:theme, creator: user, organisation: List.first(user.owned_organisations))

    conn =
      conn
      |> put(Routes.v1_theme_path(conn, :update, theme.id, @invalid_attrs))
      |> doc(operation_id: "update_theme")

    assert json_response(conn, 422)["errors"]["body_color"] == [
             "hex-code must be in the format of `#RRGGBB`"
           ]
  end

  test "index lists assets by current user", %{conn: conn} do
    user = conn.assigns.current_user
    organisation = List.first(user.owned_organisations)

    a1 = insert(:theme, creator: user, organisation: organisation)
    a2 = insert(:theme, creator: user, organisation: organisation)

    conn = get(conn, Routes.v1_theme_path(conn, :index))
    themes_index = json_response(conn, 200)["themes"]
    themes = Enum.map(themes_index, fn %{"name" => name} -> name end)
    assert List.to_string(themes) =~ a1.name
    assert List.to_string(themes) =~ a2.name
  end

  test "show renders theme details by id", %{conn: conn} do
    user = conn.assigns.current_user
    theme = insert(:theme, creator: user, organisation: List.first(user.owned_organisations))

    conn = get(conn, Routes.v1_theme_path(conn, :show, theme.id))

    assert json_response(conn, 200)["theme"]["name"] == theme.name
  end

  test "error not found for id does not exists", %{conn: conn} do
    conn = get(conn, Routes.v1_theme_path(conn, :show, Ecto.UUID.generate()))
    assert json_response(conn, 404) == "Not Found"
  end

  test "delete theme by given id", %{conn: conn} do
    user = conn.assigns[:current_user]
    theme = insert(:theme, creator: user, organisation: List.first(user.owned_organisations))
    asset = insert(:asset, organisation: List.first(user.owned_organisations))
    insert(:theme_asset, theme: theme, asset: asset)
    count_before = Theme |> Repo.all() |> length()

    ExAwsMock
    |> expect(
      :request,
      fn %ExAws.Operation.S3{} = operation ->
        assert operation.http_method == :get
        assert operation.params == %{"prefix" => "uploads/theme/theme_preview/#{theme.id}"}

        {
          :ok,
          %{
            body: %{
              contents: [%{key: "image.jpg", last_modified: "2023-03-17T13:16:11.704Z"}]
            }
          }
        }
      end
    )
    |> expect(
      :request,
      fn %ExAws.Operation.S3{} -> {:ok, %{body: "", status_code: 204}} end
    )
    |> expect(
      :request,
      fn %ExAws.Operation.S3{} = operation ->
        assert operation.http_method == :get
        assert operation.params == %{"prefix" => "uploads/assets/#{asset.id}"}

        {
          :ok,
          %{
            body: %{
              contents: [%{key: "image.jpg", last_modified: "2023-03-17T13:16:11.704Z"}]
            }
          }
        }
      end
    )
    |> expect(
      :request,
      fn %ExAws.Operation.S3{} -> {:ok, %{body: "", status_code: 204}} end
    )

    conn = delete(conn, Routes.v1_theme_path(conn, :delete, theme.id))
    assert count_before - 1 == Theme |> Repo.all() |> length()
    assert json_response(conn, 200)["name"] == theme.name
  end

  test "error not found for user from another organisation", %{conn: conn} do
    user = insert(:user)
    theme = insert(:theme, creator: user, organisation: List.first(user.owned_organisations))

    conn = get(conn, Routes.v1_theme_path(conn, :show, theme.id))

    assert json_response(conn, 404) == "Not Found"
  end
end
