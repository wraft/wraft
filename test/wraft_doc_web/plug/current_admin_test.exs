defmodule WraftDocWeb.Plug.CurrentAdminTest do
  use WraftDocWeb.ConnCase

  alias WraftDocWeb.Plug.CurrentAdmin
  import Phoenix.Controller, only: [fetch_flash: 2]

  setup do
    {:ok, conn: build_conn()}
  end

  describe "call/2" do
    test "assigns the admin user in the session when session has valid admin_id",
         %{conn: conn} do
      admin_user = insert(:internal_user)

      conn =
        conn
        |> init_test_session(%{admin_id: admin_user.id})
        |> CurrentAdmin.call([])

      assert conn.assigns[:admin_session].id == admin_user.id
      assert conn.assigns[:admin_session].email == admin_user.email
    end

    test "redirects to login page and sets flash message when session has no admin_id", %{
      conn: conn
    } do
      conn = conn |> init_test_session(%{}) |> fetch_flash([]) |> CurrentAdmin.call([])

      assert redirected_to(conn) == Routes.session_path(conn, :new)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Please login to continue."
    end

    test "redirects to login page and sets flash message when session has invalid admin_id", %{
      conn: conn
    } do
      conn =
        conn
        |> init_test_session(%{admin_id: Faker.UUID.v4()})
        |> fetch_flash([])
        |> CurrentAdmin.call([])

      assert redirected_to(conn) == Routes.session_path(conn, :new)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Please login to continue."
    end
  end
end
