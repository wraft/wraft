defmodule WraftDocWeb.SessionControllerTest do
  # DO_ME
  use WraftDocWeb.ConnCase

  setup do
    %{conn: build_conn()}
  end

  describe "new/2" do
    test "renders the login form", %{conn: conn} do
      conn = get(conn, Routes.session_path(conn, :new))

      assert html_response(conn, 200)
    end
  end

  describe "create/2" do
    test "creates a session with valid email-password combination", %{conn: conn} do
      # Create an existing user with a valid password
      user = insert(:internal_user)
      params = %{session: %{email: user.email, password: user.password}}

      conn = post(conn, Routes.session_path(conn, :create), params)

      assert redirected_to(conn) == "/admin"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Signed in successfully."
      assert get_session(conn, :admin_id) == user.id
    end

    test "flashes an info message if the user is deactivated", %{conn: conn} do
      user = insert(:internal_user, is_deactivated: true)
      params = %{session: %{email: user.email, password: user.password}}

      conn = post(conn, Routes.session_path(conn, :create), params)

      assert redirected_to(conn) == Routes.session_path(conn, :new)

      assert Phoenix.Flash.get(conn.assigns.flash, :info) ==
               "Your account has been deactivated, please contact support."

      assert get_session(conn, :admin_id) == nil
    end

    test "flashes an error message with invalid email-password combination", %{conn: conn} do
      # Create an existing user with a valid password
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

    test "flashes an error message with missing email", %{conn: conn} do
      params = %{session: %{password: "password"}}

      conn = post(conn, Routes.session_path(conn, :create), params)

      assert redirected_to(conn) == Routes.session_path(conn, :new)

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Please provide the correct login credentials to login."

      assert get_session(conn, :admin_id) == nil
    end

    test "flashes an error message with missing password", %{conn: conn} do
      user = insert(:internal_user)
      params = %{session: %{email: user.email}}

      conn = post(conn, Routes.session_path(conn, :create), params)

      assert redirected_to(conn) == Routes.session_path(conn, :new)

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Please provide the correct login credentials to login."

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
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Signed out successfully."
    end
  end
end
