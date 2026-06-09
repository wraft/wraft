defmodule WraftDocWeb.SessionControllerTest do
  use WraftDocWeb.ConnCase

  setup do
    %{conn: build_conn()}
  end

  describe "create/2" do
    test "creates a session with valid email-password combination", %{conn: conn} do
      user = insert(:internal_user)
      params = %{session: %{email: user.email, password: user.password}}

      conn = post(conn, Routes.session_path(conn, :create), params)

      assert redirected_to(conn) == "/admin"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Signed in successfully."
      assert get_session(conn, :admin_id) == user.id
      assert is_integer(get_session(conn, :admin_iat))
      assert get_session(conn, :admin_epoch) == user.session_epoch
    end

    test "flashes an error message if the user is deactivated", %{conn: conn} do
      user = insert(:internal_user, is_deactivated: true)
      params = %{session: %{email: user.email, password: user.password}}

      conn = post(conn, Routes.session_path(conn, :create), params)

      assert redirected_to(conn) == Routes.session_path(conn, :new)

      assert Phoenix.Flash.get(conn.assigns.flash, :info) ==
               "Your account has been deactivated, please contact support."

      assert get_session(conn, :admin_id) == nil
    end

    test "flashes an error message with invalid email-password combination", %{conn: conn} do
      user = insert(:internal_user)
      params = %{session: %{email: user.email, password: "wrong_password123"}}

      conn = post(conn, Routes.session_path(conn, :create), params)

      assert redirected_to(conn) == Routes.session_path(conn, :new)

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Please provide the correct login credentials to login."

      assert get_session(conn, :admin_id) == nil
    end

    test "flashes an error message with non-existent email", %{conn: conn} do
      params = %{session: %{email: "nonexistent@example.com", password: "incorrect"}}

      conn = post(conn, Routes.session_path(conn, :create), params)

      assert redirected_to(conn) == Routes.session_path(conn, :new)

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Please provide the correct login credentials to login."

      assert get_session(conn, :admin_id) == nil
    end

    test "rate-limits repeated sign-in attempts for the same email", %{conn: _conn} do
      email = "rate-limit-target-#{System.unique_integer([:positive])}@wmail.com"
      params = %{session: %{email: email, password: "incorrect-password"}}

      responses =
        for _attempt <- 1..6 do
          conn = post(build_conn(), Routes.session_path(build_conn(), :create), params)
          Phoenix.Flash.get(conn.assigns.flash, :error)
        end

      assert "Too many sign-in attempts. Please try again later." in responses
    end
  end

  describe "delete/2" do
    test "deletes the session in the conn", %{conn: conn} do
      user = insert(:internal_user)
      params = %{session: %{email: user.email, password: user.password}}

      # Creates a session
      conn = post(conn, Routes.session_path(conn, :create), params)
      conn = delete(conn, Routes.session_path(conn, :delete))

      assert get_session(conn, :admin_id) == nil
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Signed out successfully."
    end
  end
end
