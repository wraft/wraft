defmodule WraftDocWeb.ProfileControllerTest do
  use WraftDocWeb.ConnCase
  import WraftDoc.Factory

  @valid_attrs %{
    name: "Shakkir palakkal",
    dob: Timex.shift(Timex.now(), years: 27),
    gender: "male"
  }

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

  test "updates profile on valid attributes", %{conn: conn} do
    user = conn.assigns.current_user
    profile = insert(:profile, user: user)
    params = Map.merge(@valid_attrs, %{user: user})

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    conn = put(conn, Routes.v1_profile_path(conn, :update, profile.id, params))
    assert json_response(conn, 200)["profile"]["name"] == @valid_attrs.name
  end
end
