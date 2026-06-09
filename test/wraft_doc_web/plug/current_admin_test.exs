defmodule WraftDocWeb.Plug.CurrentAdminTest do
  use WraftDocWeb.ConnCase

  alias WraftDoc.InternalUsers
  alias WraftDocWeb.Plug.CurrentAdmin
  import Phoenix.Controller, only: [fetch_flash: 2]

  setup do
    {:ok, conn: build_conn()}
  end

  defp admin_session(admin), do: InternalUsers.admin_session_attrs(admin)

  defp assert_rejected(conn) do
    assert redirected_to(conn) == Routes.session_path(conn, :new)
    assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Please login to continue."
  end

  describe "call/2" do
    test "assigns the admin user when the session is valid", %{conn: conn} do
      admin_user = insert(:internal_user)

      conn =
        conn
        |> init_test_session(admin_session(admin_user))
        |> CurrentAdmin.call([])

      assert conn.assigns[:admin_session].id == admin_user.id
      assert conn.assigns[:admin_session].email == admin_user.email
    end

    test "redirects when session has no admin_id", %{conn: conn} do
      conn = conn |> init_test_session(%{}) |> fetch_flash([]) |> CurrentAdmin.call([])

      assert_rejected(conn)
    end

    test "redirects when session has invalid admin_id", %{conn: conn} do
      admin_user = insert(:internal_user)

      session = Map.put(admin_session(admin_user), "admin_id", Faker.UUID.v4())

      conn =
        conn
        |> init_test_session(session)
        |> fetch_flash([])
        |> CurrentAdmin.call([])

      assert_rejected(conn)
    end

    test "redirects a deactivated admin even with a previously valid session", %{conn: conn} do
      admin_user = insert(:internal_user)
      session = admin_session(admin_user)

      {:ok, _} =
        InternalUsers.update_internal_user(admin_user, %{
          email: admin_user.email,
          is_deactivated: true
        })

      conn =
        conn
        |> init_test_session(session)
        |> fetch_flash([])
        |> CurrentAdmin.call([])

      assert_rejected(conn)
    end

    test "redirects when the session is older than the max age", %{conn: conn} do
      admin_user = insert(:internal_user)

      stale_iat = System.system_time(:second) - 60 * 60 * 13

      session = Map.put(admin_session(admin_user), "admin_iat", stale_iat)

      conn =
        conn
        |> init_test_session(session)
        |> fetch_flash([])
        |> CurrentAdmin.call([])

      assert_rejected(conn)
    end

    test "redirects when the session has no issued-at (legacy cookie)", %{conn: conn} do
      admin_user = insert(:internal_user)

      session = Map.delete(admin_session(admin_user), "admin_iat")

      conn =
        conn
        |> init_test_session(session)
        |> fetch_flash([])
        |> CurrentAdmin.call([])

      assert_rejected(conn)
    end

    test "redirects when the session epoch is stale after a password change", %{conn: conn} do
      admin_user = insert(:internal_user)
      session = admin_session(admin_user)

      {:ok, _} =
        InternalUsers.update_internal_user(admin_user, %{
          email: admin_user.email,
          is_deactivated: false,
          password: "a-brand-new-password"
        })

      conn =
        conn
        |> init_test_session(session)
        |> fetch_flash([])
        |> CurrentAdmin.call([])

      assert_rejected(conn)
    end
  end
end
