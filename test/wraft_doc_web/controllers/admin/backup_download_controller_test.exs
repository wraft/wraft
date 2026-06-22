defmodule WraftDocWeb.BackupDownloadControllerTest do
  use WraftDocWeb.ConnCase

  import Mox
  import WraftDoc.BackupStubs

  alias WraftDoc.SystemBackups
  alias WraftDoc.SystemBackups.Event

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

  defp stub_parts_present do
    stub(ExAwsMock, :request, fn
      %ExAws.Operation.S3{http_method: :head, path: path} ->
        size = if String.ends_with?(path, ".tar"), do: tar_size(), else: dump_size()
        {:ok, %{headers: [{"Content-Length", to_string(size)}]}}
    end)
  end

  defp stub_part_missing do
    stub(ExAwsMock, :request, fn
      %ExAws.Operation.S3{http_method: :head} -> {:error, {:http_error, 404, %{}}}
    end)
  end

  defp events(kind),
    do: Event |> WraftDoc.Repo.all() |> Enum.filter(&(&1.event == kind))

  describe "POST authorize-download" do
    test "mints a token for a part, audits, and redirects to the streaming GET", %{conn: conn} do
      backup = insert(:system_backup, status: :completed)
      stub_parts_present()

      conn = post(conn, "/admin/backups/#{backup.id}/authorize-download/db")

      assert redirected_to(conn) =~ "/admin/backups/#{backup.id}/download/db?token="
      assert [mint] = events("download_authorized")
      assert mint.backup_id == backup.id
    end

    test "refuses a non-completed backup with a friendly flash", %{conn: conn} do
      {:ok, pending} = SystemBackups.create_pending(:scheduled)

      conn = post(conn, "/admin/backups/#{pending.id}/authorize-download/full")

      assert redirected_to(conn) == "/admin/backups"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "not downloadable"
      assert [_denied] = events("download_denied")
    end

    test "refuses when the part is missing from storage", %{conn: conn} do
      backup = insert(:system_backup, status: :completed)
      stub_part_missing()

      conn = post(conn, "/admin/backups/#{backup.id}/authorize-download/bucket")

      assert redirected_to(conn) == "/admin/backups"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "missing"
    end

    test "404s an unknown backup id", %{conn: conn} do
      conn = post(conn, "/admin/backups/#{Faker.UUID.v4()}/authorize-download/db")
      assert redirected_to(conn) == "/admin/backups"
      assert [_denied] = events("download_denied")
    end

    test "requires an admin session" do
      backup = insert(:system_backup, status: :completed)
      conn = post(build_conn(), "/admin/backups/#{backup.id}/authorize-download/db")
      assert redirected_to(conn) == Routes.session_path(conn, :new)
      assert events("download_denied") == []
    end
  end

  describe "GET download — single part" do
    test "streams the DB part with attachment headers and audits it", %{conn: conn, admin: admin} do
      backup = insert(:system_backup, status: :completed)
      {:ok, raw} = SystemBackups.create_download_token(admin, backup, "db")

      stub(ExAwsMock, :request, fn
        %ExAws.Operation.S3{http_method: :head, path: path} ->
          size = if String.ends_with?(path, ".tar"), do: tar_size(), else: dump_size()
          {:ok, %{headers: [{"Content-Length", to_string(size)}]}}
      end)

      stub(ExAwsMock, :stream!, fn %ExAws.S3.Download{} -> ["dump-bytes"] end)

      conn = get(conn, "/admin/backups/#{backup.id}/download/db?token=#{raw}")

      assert conn.status == 200

      assert get_resp_header(conn, "content-disposition") == [
               ~s(attachment; filename="#{SystemBackups.part_filename(backup, :db)}")
             ]

      # Filename is stamped with the backup's creation time, not the id.
      assert SystemBackups.part_filename(backup, :db) =~
               ~r/^wraft-backup-\d{8}-\d{6}-database\.dump$/

      assert get_resp_header(conn, "cache-control") == ["no-store"]
      assert conn.resp_body == "dump-bytes"
      assert [allowed] = events("download_allowed")
      assert allowed.admin_id == admin.id
    end

    test "a token cannot be used twice", %{conn: conn, admin: admin} do
      backup = insert(:system_backup, status: :completed)
      {:ok, raw} = SystemBackups.create_download_token(admin, backup, "db")

      stub(ExAwsMock, :request, fn
        %ExAws.Operation.S3{http_method: :head} -> {:ok, %{headers: [{"Content-Length", "1"}]}}
      end)

      stub(ExAwsMock, :stream!, fn %ExAws.S3.Download{} -> ["data"] end)

      first = get(conn, "/admin/backups/#{backup.id}/download/db?token=#{raw}")
      assert first.status == 200

      second = get(conn, "/admin/backups/#{backup.id}/download/db?token=#{raw}")
      assert second.status == 403
    end

    test "a db token cannot download another part", %{conn: conn, admin: admin} do
      backup = insert(:system_backup, status: :completed)
      {:ok, raw} = SystemBackups.create_download_token(admin, backup, "db")
      stub_parts_present()

      conn = get(conn, "/admin/backups/#{backup.id}/download/bucket?token=#{raw}")
      assert conn.status == 403
    end

    test "rejects a missing or garbage token", %{conn: conn} do
      backup = insert(:system_backup, status: :completed)
      stub_parts_present()

      no_token = get(conn, "/admin/backups/#{backup.id}/download/db")
      assert no_token.status == 403

      bad = get(conn, "/admin/backups/#{backup.id}/download/db?token=garbage")
      assert bad.status == 403
    end

    test "410s when the part vanished after the token was minted", %{conn: conn, admin: admin} do
      backup = insert(:system_backup, status: :completed)
      {:ok, raw} = SystemBackups.create_download_token(admin, backup, "db")
      stub_part_missing()

      conn = get(conn, "/admin/backups/#{backup.id}/download/db?token=#{raw}")
      assert conn.status == 410
    end

    test "requires an admin session even with a valid token", %{admin: admin} do
      backup = insert(:system_backup, status: :completed)
      {:ok, raw} = SystemBackups.create_download_token(admin, backup, "db")

      conn = get(build_conn(), "/admin/backups/#{backup.id}/download/db?token=#{raw}")
      assert redirected_to(conn) == Routes.session_path(conn, :new)
    end
  end

  describe "GET download — combined full" do
    test "streams a valid zip of the parts", %{conn: conn, admin: admin} do
      # db/bucket sizes gate availability (a nil size → refuse); the zip frames
      # each entry from the actual streamed bytes below (10 / 5). manifest size
      # comes from a live HEAD (4).
      backup = insert(:system_backup, status: :completed, db_size: 10, bucket_size: 5)
      {:ok, raw} = SystemBackups.create_download_token(admin, backup, "full")

      stub(ExAwsMock, :request, fn
        %ExAws.Operation.S3{http_method: :head, path: path} ->
          size =
            cond do
              String.ends_with?(path, "database.dump") -> 10
              String.ends_with?(path, ".tar") -> 5
              true -> 4
            end

          {:ok, %{headers: [{"Content-Length", to_string(size)}]}}
      end)

      stub(ExAwsMock, :stream!, fn %ExAws.S3.Download{path: path} ->
        cond do
          String.ends_with?(path, "database.dump") -> ["0123456789"]
          String.ends_with?(path, "bucket.tar") -> ["BUCKT"]
          true -> ["{ }\n"]
        end
      end)

      conn = get(conn, "/admin/backups/#{backup.id}/download/full?token=#{raw}")

      assert conn.status == 200

      assert get_resp_header(conn, "content-disposition") == [
               ~s(attachment; filename="#{SystemBackups.part_filename(backup, :full)}")
             ]

      # Full archive is now a timestamped zip.
      assert SystemBackups.part_filename(backup, :full) =~ ~r/^wraft-backup-\d{8}-\d{6}\.zip$/

      # The body is a valid zip that extracts to the three named members.
      tmp = Path.join(System.tmp_dir!(), "full-#{System.unique_integer([:positive])}.zip")
      File.write!(tmp, conn.resp_body)
      out = Path.join(System.tmp_dir!(), "full-out-#{System.unique_integer([:positive])}")
      File.mkdir_p!(out)
      {_, 0} = System.cmd("unzip", ["-o", "-qq", tmp, "-d", out])

      assert File.read!(Path.join(out, "database.dump")) == "0123456789"
      assert File.read!(Path.join(out, "bucket.tar")) == "BUCKT"
      assert File.read!(Path.join(out, "manifest.json")) == "{ }\n"

      File.rm_rf(tmp)
      File.rm_rf(out)
    end
  end
end
