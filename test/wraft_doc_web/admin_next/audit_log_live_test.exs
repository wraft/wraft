defmodule WraftDocWeb.AdminNext.AuditLogLiveTest do
  @moduledoc """
  Tests for the `/admin/audit-logs` admin LiveView.

  These tests insert `ex_audit_version` rows directly rather than going
  through tracked operations — keeps tests fast and focused on the
  page's filter / pagination / rendering behaviour.

  The schema-filter test guards against a regression where
  `AuditLogs.schema_atom/1` double-prefixed `Elixir.` to the dropdown
  value, silently no-op'ing the filter.
  """
  use WraftDocWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import WraftDoc.Factory

  alias WraftDoc.ExAudit.Version
  alias WraftDoc.Repo

  @path "/admin/audit-logs"

  setup do
    admin = insert(:internal_user)

    conn =
      Plug.Test.init_test_session(
        Phoenix.ConnTest.build_conn(),
        WraftDoc.InternalUsers.admin_session_attrs(admin)
      )

    {:ok, conn: conn, admin: admin}
  end

  describe "mount/render" do
    test "renders the page with empty state when no events exist", %{conn: conn} do
      Repo.delete_all(Version)

      {:ok, _view, html} = live(conn, @path)

      assert html =~ "Audit Logs"
      assert html =~ "No audit events match"
    end

    test "renders rows from ex_audit_version with action badges", %{conn: conn} do
      user = insert(:user)

      insert_version!(action: :created, user_id: user.id, entity_schema: WraftDoc.Themes.Theme)
      insert_version!(action: :updated, user_id: user.id, entity_schema: WraftDoc.Themes.Theme)
      insert_version!(action: :deleted, user_id: user.id, entity_schema: WraftDoc.Themes.Theme)

      {:ok, _view, html} = live(conn, @path)

      assert html =~ "Created"
      assert html =~ "Updated"
      assert html =~ "Deleted"
      assert html =~ user.email
    end

    test "shows 'System' when the version has no user", %{conn: conn} do
      insert_version!(action: :created, user_id: nil, entity_schema: WraftDoc.Themes.Theme)

      {:ok, _view, html} = live(conn, @path)

      assert html =~ "System"
    end
  end

  describe "action filter" do
    test "narrows the visible result set to the chosen action", %{conn: conn} do
      created_id = Ecto.UUID.generate()
      deleted_id = Ecto.UUID.generate()

      insert_version!(
        action: :created,
        entity_id: created_id,
        entity_schema: WraftDoc.Themes.Theme
      )

      insert_version!(
        action: :deleted,
        entity_id: deleted_id,
        entity_schema: WraftDoc.Themes.Theme
      )

      {:ok, view, _html} = live(conn, @path)

      html =
        view
        |> form("form[phx-change='filter']", %{"action" => "deleted", "schema" => "", "q" => ""})
        |> render_change()

      assert html =~ short_id(deleted_id)
      refute html =~ short_id(created_id)
    end
  end

  describe "schema filter" do
    # Regression test: previously `schema_atom/1` prepended an extra "Elixir."
    # to the dropdown value, so this filter silently returned all rows.
    test "narrows the visible result set to the chosen entity schema", %{conn: conn} do
      theme_id = Ecto.UUID.generate()
      block_id = Ecto.UUID.generate()

      insert_version!(action: :created, entity_id: theme_id, entity_schema: WraftDoc.Themes.Theme)
      insert_version!(action: :created, entity_id: block_id, entity_schema: WraftDoc.Blocks.Block)

      {:ok, view, _html} = live(conn, @path)

      schema_value = Atom.to_string(WraftDoc.Themes.Theme)

      html =
        view
        |> form("form[phx-change='filter']", %{
          "action" => "",
          "schema" => schema_value,
          "q" => ""
        })
        |> render_change()

      assert html =~ short_id(theme_id)
      refute html =~ short_id(block_id)
    end
  end

  describe "detail modal" do
    test "clicking a row opens the detail modal with metadata and diff", %{conn: conn} do
      user = insert(:user, name: "Detail User", email: "detail@example.test")

      version =
        insert_version!(
          action: :updated,
          user_id: user.id,
          entity_schema: WraftDoc.Themes.Theme,
          patch: %{name: {:changed, {:primitive_change, "Old Name", "New Name"}}}
        )

      {:ok, view, _html} = live(conn, @path)

      html = view |> element("tr[phx-value-id='#{version.id}']") |> render_click()

      assert html =~ "Detail User"
      assert html =~ "detail@example.test"
      assert html =~ "Old Name"
      assert html =~ "New Name"
      assert_patch(view, "/admin/audit-logs?id=#{version.id}")
    end

    test "close button dismisses the modal and clears the URL", %{conn: conn} do
      version =
        insert_version!(
          action: :created,
          patch: %{title: {:added, "Hello"}}
        )

      {:ok, view, _html} = live(conn, "#{@path}?id=#{version.id}")

      assert render(view) =~ "Hello"

      view |> element("button[aria-label='Close']") |> render_click()

      refute render(view) =~ "Hello"
      assert_patch(view, @path)
    end

    test "unknown id does not crash and shows the list view", %{conn: conn} do
      insert_version!(action: :created, entity_schema: WraftDoc.Themes.Theme)

      {:ok, _view, html} = live(conn, "#{@path}?id=99999999")

      assert html =~ "Audit Logs"
      # Modal not rendered when id doesn't resolve
      refute html =~ "aria-label=\"Close\""
    end

    test "non-numeric id is rejected without crashing", %{conn: conn} do
      {:ok, _view, html} = live(conn, "#{@path}?id=not-a-number")
      assert html =~ "Audit Logs"
    end
  end

  describe "search filter" do
    test "matches against the actor's email", %{conn: conn} do
      alice = insert(:user, name: "Alice", email: "alice@example.test")
      bob = insert(:user, name: "Bob", email: "bob@example.test")

      alice_entity = Ecto.UUID.generate()
      bob_entity = Ecto.UUID.generate()

      insert_version!(
        action: :created,
        user_id: alice.id,
        entity_id: alice_entity,
        entity_schema: WraftDoc.Themes.Theme
      )

      insert_version!(
        action: :created,
        user_id: bob.id,
        entity_id: bob_entity,
        entity_schema: WraftDoc.Themes.Theme
      )

      {:ok, view, _html} = live(conn, @path)

      html =
        view
        |> form("form[phx-change='filter']", %{"action" => "", "schema" => "", "q" => "alice"})
        |> render_change()

      assert html =~ short_id(alice_entity)
      refute html =~ short_id(bob_entity)
    end
  end

  # ---- helpers --------------------------------------------------------------

  defp insert_version!(attrs) do
    defaults = %{
      patch: %{},
      entity_id: Ecto.UUID.generate(),
      entity_schema: WraftDoc.Themes.Theme,
      action: :created,
      recorded_at: DateTime.utc_now(),
      rollback: false,
      user_id: nil
    }

    %Version{}
    |> Ecto.Changeset.change(Map.merge(defaults, Map.new(attrs)))
    |> Repo.insert!()
  end

  defp short_id(uuid), do: uuid |> String.split("-", parts: 2) |> List.first()
end
