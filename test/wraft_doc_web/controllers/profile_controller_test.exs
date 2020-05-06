defmodule WraftDocWeb.Api.V1.ProfileControllerTest do
  use WraftDocWeb.ConnCase
  import WraftDoc.Factory

  @valid_attrs %{
    name: "Shakkir palakkal",
    dob: Date.new(2020, 2, 29) |> elem(1),
    gender: "male"
  }

  setup %{conn: conn} do
    profile = insert(:profile)
    user = profile.user

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

  test "updates profile on valid attributes", %{conn: conn} do
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    conn = put(conn, Routes.v1_profile_path(conn, :update), @valid_attrs)
    assert json_response(conn, 200)["name"] == @valid_attrs.name
  end

  # test "render profile on id exists", %{conn: conn} do
  #   profile = insert(:profile)

  #   conn =
  #     build_conn()
  #     |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
  #     |> assign(:current_user, conn.assigns.current_user)

  #   conn = get(conn, Routes.v1_profile_path(conn, :show, profile.uuid))
  #   assert json_response(conn, 200)["name"] == profile.name
  # end

  # test "error not found for id does not exist", %{conn: conn} do
  #   conn =
  #     build_conn()
  #     |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
  #     |> assign(:current_user, conn.assigns.current_user)

  #   conn = get(conn, Routes.v1_profile_path(conn, :show, Ecto.UUID.autogenerate()))
  #   assert json_response(conn, 404) == "Not Found"
  # end

  test "renders current profile ", %{conn: conn} do
    current_user = conn.assigns.current_user

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    conn = get(conn, Routes.v1_profile_path(conn, :show_current_profile))

    assert json_response(conn, 200)["name"] == current_user.name
  end
end
