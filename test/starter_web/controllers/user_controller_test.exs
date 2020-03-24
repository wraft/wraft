defmodule WraftDocWeb.UserControllerTest do
  use WraftDocWeb.ConnCase
  import WraftDoc.Factory
  alias WraftDoc.Account.User

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

  test "user signed in on email and password" do
    user = insert(:user)

    conn =
      build_conn
      |> post(
        Routes.v1_user_path(conn, :signin, %{
          email: user.email,
          password: user.password
        })
      )

    assert json_response(conn, 200)["user"]["email"] == user.email
  end

  test "returns the current logined user", %{conn: conn} do
    user = conn.assigns.current_user

    conn =
      build_conn
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    conn = get(conn, Routes.v1_user_path(conn, :me))
    assert json_response(conn, 200)["me"]["email"] == user.email
  end
end
