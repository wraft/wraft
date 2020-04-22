defmodule WraftDocWeb.UserControllerTest do
  use WraftDocWeb.ConnCase
  import WraftDoc.Factory
  alias WraftDoc.Repo

  setup %{conn: conn} do
    profile = insert(:profile)
    user = profile.user |> Repo.preload([:profile, :role, :organisation])

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

    conn = build_conn()

    conn =
      conn
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
      build_conn()
      |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
      |> assign(:current_user, conn.assigns.current_user)

    conn = get(conn, Routes.v1_user_path(conn, :me))
    assert json_response(conn, 200)["email"] == user.email
  end

  # test "generates token and renders confirmation message", %{conn: conn} do
  #   user = insert(:user)

  #   conn =
  #     build_conn()
  #     |> put_req_header("authorization", "Bearer #{conn.assigns.token}")
  #     |> assign(:current_user, conn.assigns.current_user)

  #   count_before = AuthToken |> Repo.all() |> length()
  #   conn = get(conn, Routes.v1_user_path(conn, :create_token))
  #   count_after = AuthToken |> Repo.all() |> length()

  #   assert json_response(conn, 200)["info"] ==
  #            "A password reset link has been sent to your email.!"

  #   assert count_before + 1 = count_after
  # end
end
