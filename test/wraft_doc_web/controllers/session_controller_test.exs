defmodule WraftDocWeb.SessionControllerTest do
  use WraftDocWeb.ConnCase

  setup do
    %{conn: build_conn()}
  end

  describe "create/2" do
    test "creates a session with valid email-password combination", %{conn: conn} do
      # Create an existing user with a valid password
      user = insert(:internal_user)
      params = %{session: %{email: user.email, password: user.password}}

      conn = post(conn, Routes.session_path(conn, :create), params)

      assert redirected_to(conn) == "/admin"
      assert get_flash(conn, :info) == "Signed in successfully."
      assert get_session(conn, :admin_id) == user.id
    end

    test "flashes an error message with invalid email-password combination", %{conn: conn} do
      # Create an existing user with a valid password
      user = insert(:internal_user)
      params = %{session: %{email: user.email, password: "wrong_password123"}}

      conn = post(conn, Routes.session_path(conn, :create), params)

      assert redirected_to(conn) == Routes.session_path(conn, :new)
      assert get_flash(conn, :error) == "Please provide the correct login credentials to login."
      assert get_session(conn, :user_id) == nil
    end

    test "flashes an error message with non-existent email", %{conn: conn} do
      params = %{session: %{email: "nonexistent@example.com", password: "incorrect"}}

      conn = post(conn, Routes.session_path(conn, :create), params)

      assert redirected_to(conn) == Routes.session_path(conn, :new)
      assert get_flash(conn, :error) == "Please provide the correct login credentials to login."
      assert get_session(conn, :admin_id) == nil
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
      assert get_flash(conn, :info) == "Signed out successfully."
    end
  end
end
