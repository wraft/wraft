defmodule WraftDoc.Workers.SystemRestoreWorkerTest do
  use WraftDoc.DataCase, async: false

  import Mox
  import WraftDoc.BackupStubs

  alias WraftDoc.SystemBackups
  alias WraftDoc.Workers.SystemRestoreWorker

  setup :verify_on_exit!

  setup do
    put_backup_config()
    :ok
  end

  defp stub_restore_io do
    # download (db dump, bucket.tar), put_bucket, uploads all succeed.
    stub(ExAwsMock, :stream!, fn _op -> [] end)

    stub(ExAwsMock, :request, fn
      %ExAws.S3.Download{} -> {:ok, :done}
      %ExAws.S3.Upload{} -> {:ok, %{}}
      %ExAws.Operation.S3{http_method: :put} -> {:ok, %{}}
      _ -> {:ok, %{}}
    end)
  end

  test "restores into the target db + bucket and marks completed" do
    backup = insert(:system_backup, status: :completed)
    {:ok, restore} = SystemBackups.start_restore(insert(:internal_user), backup)
    test_pid = self()

    # createdb + pg_restore + tar succeed; capture the target DB name.
    stub(CmdRunnerMock, :cmd, fn
      "createdb", [target], opts ->
        send(test_pid, {:createdb, target, opts[:env]})
        {"", 0}

      "pg_restore", args, _opts ->
        send(test_pid, {:pg_restore, args})
        {"", 0}

      "tar", _args, _opts ->
        {"", 0}
    end)

    stub_restore_io()

    assert {:ok, :restored} = perform_job(SystemRestoreWorker, %{"restore_id" => restore.id})

    fresh = SystemBackups.get_restore(restore.id)
    assert fresh.status == :completed

    assert_received {:createdb, target, env}
    assert target == restore.target_database
    # createdb connects to the maintenance DB, not the live app DB.
    assert {"PGDATABASE", "postgres"} = List.keyfind(env, "PGDATABASE", 0)
    assert_received {:pg_restore, args}
    assert "--dbname" in args
    assert restore.target_database in args
  end

  test "createdb failure marks the restore failed (live DB untouched)" do
    backup = insert(:system_backup, status: :completed)
    {:ok, restore} = SystemBackups.start_restore(insert(:internal_user), backup)

    stub(ExAwsMock, :request, fn %ExAws.S3.Download{} -> {:ok, :done} end)

    expect(CmdRunnerMock, :cmd, fn "createdb", _args, _opts ->
      {"createdb: error: database already exists", 1}
    end)

    assert {:error, _reason} = perform_job(SystemRestoreWorker, %{"restore_id" => restore.id})
    assert SystemBackups.get_restore(restore.id).status == :failed
  end

  test "start_restore refuses a non-completed backup" do
    {:ok, pending} = SystemBackups.create_pending(:scheduled)

    assert {:error, :not_restorable} =
             SystemBackups.start_restore(insert(:internal_user), pending)
  end

  test "restores are blocked when the feature flag is off" do
    Application.put_env(
      :wraft_doc,
      :system_backup,
      Keyword.put(Application.get_env(:wraft_doc, :system_backup), :enabled, false)
    )

    backup = insert(:system_backup, status: :completed)
    assert {:error, :disabled} = SystemBackups.start_restore(insert(:internal_user), backup)

    assert {:error, :disabled} =
             SystemBackups.start_remote_restore(insert(:internal_user), backup, %{
               remote_database_url: "postgres://u:p@h:5432/d",
               remote_s3_endpoint: "https://m",
               remote_s3_bucket: "b",
               remote_s3_access_key_id: "k",
               remote_s3_secret: "s"
             })
  end

  test "start_restore blocks a second concurrent restore" do
    backup = insert(:system_backup, status: :completed)
    assert {:ok, _} = SystemBackups.start_restore(insert(:internal_user), backup)

    assert {:error, :restore_in_progress} =
             SystemBackups.start_restore(insert(:internal_user), backup)
  end

  test "remote restore runs pg_restore --clean on the remote DB and mirrors to the remote bucket" do
    backup = insert(:system_backup, status: :completed)

    remote = %{
      remote_database_url: "postgres://ru:rp@remote-host:5432/wraft_remote",
      remote_s3_endpoint: "https://minio.remote",
      remote_s3_bucket: "wraft-remote",
      remote_s3_access_key_id: "AKIA",
      remote_s3_secret: "supersecret"
    }

    {:ok, restore} = SystemBackups.start_remote_restore(insert(:internal_user), backup, remote)
    assert restore.target_type == :remote
    test_pid = self()

    # No createdb for remote; pg_restore uses --clean against the remote DB.
    stub(CmdRunnerMock, :cmd, fn
      "pg_restore", args, opts ->
        send(test_pid, {:pg_restore, args, opts[:env]})
        {"", 0}

      "tar", _args, _opts ->
        {"", 0}
    end)

    # Source downloads use request/1 (the local backup bucket).
    stub(ExAwsMock, :request, fn %ExAws.S3.Download{} -> {:ok, :done} end)

    # Remote ops use request/2 with per-request overrides (endpoint + creds).
    stub(ExAwsMock, :request, fn
      %ExAws.Operation.S3{http_method: :put}, overrides ->
        send(test_pid, {:put_bucket, overrides})
        {:ok, %{}}

      _op, _overrides ->
        {:ok, %{}}
    end)

    assert {:ok, :restored} = perform_job(SystemRestoreWorker, %{"restore_id" => restore.id})
    assert SystemBackups.get_restore(restore.id).status == :completed

    assert_received {:pg_restore, args, env}
    assert "--clean" in args
    assert "wraft_remote" in args
    assert {"PGHOST", "remote-host"} = List.keyfind(env, "PGHOST", 0)
    assert_received {:put_bucket, overrides}
    assert overrides[:host] == "minio.remote"
    assert overrides[:secret_access_key] == "supersecret"
  end

  describe "remote-restore guards" do
    defp valid_remote do
      %{
        remote_database_url: "postgres://ru:rp@remote-host:5432/wraft_remote",
        remote_s3_endpoint: "https://minio.remote",
        remote_s3_bucket: "wraft-remote",
        remote_s3_access_key_id: "AKIA",
        remote_s3_secret: "secret"
      }
    end

    test "remote restore is blocked unless explicitly enabled" do
      put_backup_config(enabled: true, remote_restore_enabled: false)
      backup = insert(:system_backup, status: :completed)

      assert {:error, :remote_restore_disabled} =
               SystemBackups.start_remote_restore(insert(:internal_user), backup, valid_remote())
    end

    test "rejects a remote host that resolves to a private/loopback address" do
      put_backup_config(enabled: true, remote_restore_enabled: true, remote_allowed_hosts: [])
      backup = insert(:system_backup, status: :completed)

      remote = %{
        valid_remote()
        | remote_database_url: "postgres://u:p@127.0.0.1:5432/d",
          remote_s3_endpoint: "https://127.0.0.1"
      }

      assert {:error, reason} =
               SystemBackups.start_remote_restore(insert(:internal_user), backup, remote)

      assert reason =~ "private/loopback"
    end

    test "refuses a remote target that is the live database" do
      put_backup_config(enabled: true, remote_restore_enabled: true, remote_allowed_hosts: :any)
      backup = insert(:system_backup, status: :completed)
      remote = %{valid_remote() | remote_database_url: System.get_env("DATABASE_URL")}

      assert {:error, reason} =
               SystemBackups.start_remote_restore(insert(:internal_user), backup, remote)

      assert reason =~ "live database"
    end

    test "rejects a remote Postgres URL with no database name" do
      put_backup_config(enabled: true, remote_restore_enabled: true, remote_allowed_hosts: :any)
      backup = insert(:system_backup, status: :completed)
      remote = %{valid_remote() | remote_database_url: "postgres://u:p@remote-host:5432"}

      assert {:error, reason} =
               SystemBackups.start_remote_restore(insert(:internal_user), backup, remote)

      assert reason =~ "database name"
    end
  end

  test "reconcile_stale_restores fails an orphaned running restore" do
    backup = insert(:system_backup, status: :completed)

    stale =
      DateTime.utc_now() |> DateTime.add(-8 * 3600, :second) |> DateTime.truncate(:second)

    restore = insert(:system_backup_restore, backup: backup, status: :running, started_at: stale)

    assert SystemBackups.reconcile_stale_restores() >= 1
    assert SystemBackups.get_restore(restore.id).status == :failed
    # The wedge is cleared — a new restore can start.
    refute SystemBackups.restore_in_flight?()
  end
end
