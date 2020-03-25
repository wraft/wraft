defmodule WraftDocWeb.ThemeControllerTest do
  @moduledoc """
  Test module for theme controller
  """
  use WraftDocWeb.ConnCase

  import WraftDoc.Factory
  alias WraftDoc.{Document.Theme, Repo}

  @valid_attrs %{
    name: "Official Letter Theme",
    font: "Malery",
    typescale: %{h1: "10", p: "6", h2: "8"},
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

  test "create themes by valid attrrs", %{conn: conn} do
    user = conn.assigns.current_user

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, user)

    count_before = Theme |> Repo.all() |> length()

    conn =
      post(conn, Routes.v1_theme_path(conn, :create, @valid_attrs))
      |> doc(operation_id: "create_theme")

    assert count_before + 1 == Theme |> Repo.all() |> length()
    assert json_response(conn, 200)["name"] == @valid_attrs.name
  end

  test "does not create themes by invalid attrs", %{conn: conn} do
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    count_before = Theme |> Repo.all() |> length()

    conn =
      post(conn, Routes.v1_theme_path(conn, :create, @invalid_attrs))
      |> doc(operation_id: "create_theme")

    assert json_response(conn, 422)["errors"]["name"] == ["can't be blank"]
    assert count_before == Theme |> Repo.all() |> length()
  end

  test "update themes on valid attrs ", %{conn: conn} do
    user = conn.assigns.current_user
    organisation = user.organisation
    theme = insert(:theme, creator: user)
    content_type = insert(:content_type)
    file = %Plug.Upload{content_type: content_type, filename: "file", path: "/tmp"}
    params = Map.merge(@valid_attrs, %{organisation: organisation, creator: user, file: file})

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    count_before = Theme |> Repo.all() |> length()

    conn =
      put(conn, Routes.v1_theme_path(conn, :update, theme.uuid, params))
      |> doc(operation_id: "update_theme")

    assert json_response(conn, 200)["name"] == @valid_attrs.name
    assert count_before == Theme |> Repo.all() |> length()
  end

  test "does't update themes for invalid attrs", %{conn: conn} do
    theme = insert(:theme, creator: conn.assigns.current_user)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    conn =
      put(conn, Routes.v1_theme_path(conn, :update, theme.uuid, @invalid_attrs))
      |> doc(operation_id: "update_theme")

    assert json_response(conn, 422)["errors"]["file"] == ["can't be blank"]
  end

  test "index lists assests by current user", %{conn: conn} do
    user = conn.assigns.current_user

    a1 = insert(:theme, creator: user, organisation: user.organisation)
    a2 = insert(:theme, creator: user, organisation: user.organisation)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    conn = get(conn, Routes.v1_theme_path(conn, :index))
    themes_index = json_response(conn, 200)["themes"]
    themes = Enum.map(themes_index, fn %{"name" => name} -> name end)
    assert List.to_string(themes) =~ a1.name
    assert List.to_string(themes) =~ a2.name
  end

  test "show renders theme details by id", %{conn: conn} do
    theme = insert(:theme, creator: conn.assigns.current_user)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    conn = get(conn, Routes.v1_theme_path(conn, :show, theme.uuid))

    assert json_response(conn, 200)["theme"]["name"] == theme.name
  end

  test "error not found for id does not exists", %{conn: conn} do
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    conn = get(conn, Routes.v1_theme_path(conn, :show, Ecto.UUID.generate()))
    assert json_response(conn, 404) == "Not Found"
  end

  test "delete theme by given id", %{conn: conn} do
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    theme = insert(:theme, creator: conn.assigns.current_user)
    count_before = Theme |> Repo.all() |> length()

    conn = delete(conn, Routes.v1_theme_path(conn, :delete, theme.uuid))
    assert count_before - 1 == Theme |> Repo.all() |> length()
    assert json_response(conn, 200)["name"] == theme.name
  end
end
