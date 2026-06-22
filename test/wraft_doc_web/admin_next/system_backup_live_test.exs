defmodule WraftDocWeb.AdminNext.SystemBackupLiveTest do
  use WraftDocWeb.ConnCase

  import Mox
  import Phoenix.LiveViewTest
  import WraftDoc.BackupStubs

  alias WraftDoc.SystemBackups

  @path "/admin/backups"

  setup :verify_on_exit!

  setup do
    put_backup_config()

    admin = insert(:internal_user)

    conn =
      Plug.Test.init_test_session(
        Phoenix.ConnTest.build_conn(),
        WraftDoc.InternalUsers.admin_session_attrs(admin)
      )

    {:ok, conn: conn, admin: admin}
  end

  describe "authentication" do
    test "redirects to sign-in without an admin session" do
      conn = Phoenix.ConnTest.build_conn()
      assert {:error, {:redirect, %{to: "/admin/signin"}}} = live(conn, @path)
    end

    test "rejects a deactivated admin even with a previously valid session", %{
      conn: conn,
      admin: admin
    } do
      {:ok, _} =
        WraftDoc.InternalUsers.update_internal_user(admin, %{
          email: admin.email,
          is_deactivated: true
        })

      assert {:error, {:redirect, %{to: "/admin/signin"}}} = live(conn, @path)
    end
  end

  describe "index" do
    test "renders the backup list with status, actor, and part sizes", %{conn: conn} do
      admin2 = insert(:internal_user)

      _completed =
        insert(:system_backup,
          status: :completed,
          trigger_type: :manual,
          creator: admin2,
          db_size: 1_048_576,
          bucket_size: 2_097_152
        )

      _scheduled = insert(:system_backup, status: :completed, trigger_type: :scheduled)

      {:ok, _view, html} = live(conn, @path)

      assert html =~ "Backup history"
      assert html =~ admin2.email
      # Scheduled rows render the System actor.
      assert html =~ "System"
      # Per-part sizes (1 MB DB / 2 MB bucket).
      assert html =~ "1.0 MB"
      assert html =~ "2.0 MB"
    end

    test "shows the empty state when no backups exist", %{conn: conn} do
      {:ok, _view, html} = live(conn, @path)
      assert html =~ "No backups yet"
    end

    test "Database/Bucket/Full download forms render for completed backups", %{conn: conn} do
      {:ok, pending} = SystemBackups.create_pending(:scheduled)
      {:ok, _running} = SystemBackups.mark_running(pending)
      completed = insert(:system_backup, status: :completed)

      {:ok, _view, html} = live(conn, @path)

      assert html =~ "/admin/backups/#{completed.id}/authorize-download/db"
      assert html =~ "/admin/backups/#{completed.id}/authorize-download/bucket"
      assert html =~ "/admin/backups/#{completed.id}/authorize-download/full"
      refute html =~ "/admin/backups/#{completed.id}/authorize-download/public"
      refute html =~ "/admin/backups/#{pending.id}/authorize-download"
    end

    test "Delete and Restore buttons render for completed backups", %{conn: conn} do
      completed = insert(:system_backup, status: :completed)
      {:ok, view, _html} = live(conn, @path)

      assert has_element?(view, "button[phx-value-id='#{completed.id}']", "Delete")
      assert has_element?(view, "button[phx-value-id='#{completed.id}']", "Restore")
    end

    test "failed backups surface their error", %{conn: conn} do
      insert(:system_backup, status: :failed, error: "pg_dump failed (exit 1)")

      {:ok, _view, html} = live(conn, @path)
      assert html =~ "pg_dump failed"
    end
  end

  describe "take_backup" do
    test "creates a pending backup and reports it", %{conn: conn} do
      {:ok, view, _html} = live(conn, @path)

      html = view |> element("button", "Take backup") |> render_click()

      assert html =~ "Backup started"
      assert SystemBackups.in_flight?()
    end

    test "button is disabled while a backup is in flight", %{conn: conn} do
      {:ok, _pending} = SystemBackups.create_pending(:scheduled)

      {:ok, view, _html} = live(conn, @path)

      assert view |> element("button[disabled]", "Take backup") |> has_element?()
    end

    test "reports the cooldown when one is configured and re-triggering too soon", %{
      conn: conn,
      admin: admin
    } do
      {:ok, _} = SystemBackups.update_schedule(%{"manual_cooldown_minutes" => "60"})
      {:ok, backup} = SystemBackups.create_pending(:manual, admin)
      {:ok, running} = SystemBackups.mark_running(backup)
      {:ok, _} = SystemBackups.mark_completed(running, %{file_path: "k", file_size: 1})

      {:ok, view, _html} = live(conn, @path)

      html = view |> element("button", "Take backup") |> render_click()
      assert html =~ "limited to one per hour"
    end

    test "feature flag off disables the button and explains why", %{conn: conn} do
      Application.put_env(
        :wraft_doc,
        :system_backup,
        Keyword.put(Application.get_env(:wraft_doc, :system_backup), :enabled, false)
      )

      {:ok, view, html} = live(conn, @path)

      assert html =~ "Feature disabled"
      assert view |> element("button[disabled]", "Take backup") |> has_element?()
    end
  end

  describe "delete_backup" do
    test "deletes the backup's objects and soft-deletes the row", %{conn: conn} do
      backup = insert(:system_backup, status: :completed)

      # Prefix listing + object deletes succeed.
      stub(ExAwsMock, :stream!, fn %ExAws.Operation.S3{params: params} ->
        [%{key: (params["prefix"] || "") <> "database.dump"}]
      end)

      stub(ExAwsMock, :request, fn %ExAws.Operation.S3{http_method: :delete} -> {:ok, %{}} end)

      {:ok, view, _html} = live(conn, @path)
      html = render_click(view, "delete_backup", %{"id" => backup.id})

      assert html =~ "Backup deleted"
      assert SystemBackups.get_backup(backup.id).status == :deleted
    end
  end

  describe "restore_backup" do
    test "starts a restore into a new target db/bucket and reports it", %{conn: conn} do
      backup = insert(:system_backup, status: :completed)

      {:ok, view, _html} = live(conn, @path)
      html = render_click(view, "restore_backup", %{"id" => backup.id})

      assert html =~ "Restore started into"
      restore = SystemBackups.latest_restore_for(backup.id)
      assert restore.status == :pending
      assert restore.target_type == :local
      assert restore.target_database =~ "wraft_restored_"
      assert restore.target_bucket =~ "wraft-restored-"
    end

    test "remote restore (another site) starts a remote restore", %{conn: conn} do
      backup = insert(:system_backup, status: :completed)
      {:ok, view, _html} = live(conn, @path)

      _ = render_click(view, "open_remote_restore", %{"id" => backup.id})

      html =
        render_submit(view, "submit_remote_restore", %{
          "remote" => %{
            "remote_database_url" => "postgres://u:p@remote:5432/wraft",
            "remote_s3_endpoint" => "https://minio.remote",
            "remote_s3_bucket" => "wraft",
            "remote_s3_access_key_id" => "AKIA",
            "remote_s3_secret" => "secret"
          }
        })

      assert html =~ "Remote restore started"
      restore = SystemBackups.latest_restore_for(backup.id)
      assert restore.target_type == :remote
      assert restore.remote_s3_endpoint == "https://minio.remote"
      # Secret is encrypted at rest, decrypts back via the schema type.
      assert restore.remote_s3_secret == "secret"
    end

    test "blocks a second restore while one is in progress", %{conn: conn} do
      backup = insert(:system_backup, status: :completed)
      insert(:system_backup_restore, status: :running, backup: backup)

      {:ok, view, _html} = live(conn, @path)
      html = render_click(view, "restore_backup", %{"id" => backup.id})

      assert html =~ "already in progress"
    end
  end
end
