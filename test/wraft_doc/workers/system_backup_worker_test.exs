defmodule WraftDoc.Workers.SystemBackupWorkerTest do
  use WraftDoc.DataCase, async: false

  import Mox
  import WraftDoc.BackupStubs

  alias WraftDoc.SystemBackups
  alias WraftDoc.SystemBackups.Backup
  alias WraftDoc.Workers.SystemBackupRetentionWorker
  alias WraftDoc.Workers.SystemBackupWorker

  setup :verify_on_exit!

  setup do
    put_backup_config()
    :ok
  end

  describe "trigger_manual/1" do
    test "creates a pending row and enqueues exactly one job" do
      admin = insert(:internal_user)

      assert {:ok, %Backup{status: :pending} = backup} = SystemBackups.trigger_manual(admin)

      assert_enqueued(
        worker: SystemBackupWorker,
        args: %{"backup_id" => backup.id}
      )
    end

    test "refuses when the feature flag is off" do
      Application.put_env(
        :wraft_doc,
        :system_backup,
        Keyword.put(Application.get_env(:wraft_doc, :system_backup), :enabled, false)
      )

      admin = insert(:internal_user)

      assert {:error, :disabled} = SystemBackups.trigger_manual(admin)
      refute_enqueued(worker: SystemBackupWorker)
    end

    test "second trigger while one is in flight creates no second row or job" do
      admin = insert(:internal_user)

      assert {:ok, _backup} = SystemBackups.trigger_manual(admin)
      # No cooldown by default, so the partial unique index is what blocks
      # the second trigger while one is pending/running.
      assert {:error, :backup_in_progress} = SystemBackups.trigger_manual(admin)

      assert Repo.aggregate(Backup, :count) == 1
      assert [_only_one] = all_enqueued(worker: SystemBackupWorker)
    end
  end

  describe "perform/1" do
    test "manual happy path: completes the backup and enqueues retention" do
      admin = insert(:internal_user)
      {:ok, backup} = SystemBackups.create_pending(:manual, admin)

      stub_cmds()
      stub_s3(["organisations/org1/file.pdf"])

      assert {:ok, :completed} =
               perform_job(SystemBackupWorker, %{"backup_id" => backup.id})

      fresh = SystemBackups.get_backup(backup.id)
      assert fresh.status == :completed
      assert fresh.file_path == "system/backups/#{backup.id}/"
      assert fresh.db_size == dump_size()
      assert fresh.bucket_size == tar_size()

      assert_enqueued(worker: SystemBackupRetentionWorker)
    end

    test "scheduled fire creates its own pending row and completes it" do
      stub_cmds()
      stub_s3(["organisations/org1/file.pdf"])

      assert {:ok, :completed} =
               perform_job(SystemBackupWorker, %{"trigger_type" => "scheduled"})

      assert [backup] = Repo.all(Backup)
      assert backup.trigger_type == :scheduled
      assert backup.creator_id == nil
      assert backup.status == :completed
    end

    test "scheduled fire while a backup is in flight is a logged no-op" do
      {:ok, _in_flight} = SystemBackups.create_pending(:manual, insert(:internal_user))

      assert {:ok, :skipped} =
               perform_job(SystemBackupWorker, %{"trigger_type" => "scheduled"})

      assert Repo.aggregate(Backup, :count) == 1
    end

    test "feature flag off: perform no-ops without touching anything" do
      Application.put_env(
        :wraft_doc,
        :system_backup,
        Keyword.put(Application.get_env(:wraft_doc, :system_backup), :enabled, false)
      )

      assert {:ok, :disabled} =
               perform_job(SystemBackupWorker, %{"trigger_type" => "scheduled"})

      assert Repo.aggregate(Backup, :count) == 0
    end

    test "engine failure lands the row in failed with a scrubbed error" do
      {:ok, backup} = SystemBackups.create_pending(:scheduled)
      database_url = System.get_env("DATABASE_URL")

      stub_cmds()

      expect(CmdRunnerMock, :cmd, 2, fn
        "df", _args, _opts ->
          {"Filesystem 1K-blocks Used Available Capacity Mounted\n/dev/x 1 1 999999999 1% /", 0}

        "pg_dump", _args, _opts ->
          {"could not connect using #{database_url}", 1}
      end)

      assert {:error, _reason} =
               perform_job(SystemBackupWorker, %{"backup_id" => backup.id})

      fresh = SystemBackups.get_backup(backup.id)
      assert fresh.status == :failed
      assert fresh.error =~ "pg_dump failed"
      refute fresh.error =~ database_url
      refute_enqueued(worker: SystemBackupRetentionWorker)
    end

    test "a stale-heartbeat orphan is reconciled at the start of any run" do
      {:ok, orphan} = SystemBackups.create_pending(:scheduled)
      {:ok, orphan} = SystemBackups.mark_running(orphan)

      stale =
        DateTime.utc_now()
        |> DateTime.add(-SystemBackups.heartbeat_staleness_seconds() - 60, :second)
        |> DateTime.truncate(:second)

      {:ok, _} = orphan |> Backup.update_changeset(%{heartbeat_at: stale}) |> Repo.update()

      stub_cmds()
      stub_s3(["organisations/org1/file.pdf"])

      # The orphan is flipped to failed, freeing the index slot, so this
      # scheduled run proceeds to a fresh completed backup.
      assert {:ok, :completed} =
               perform_job(SystemBackupWorker, %{"trigger_type" => "scheduled"})

      assert SystemBackups.get_backup(orphan.id).status == :failed
    end

    test "Lifeline-discard simulation: row reconciled to failed mid-run never resurrects" do
      {:ok, backup} = SystemBackups.create_pending(:scheduled)
      app_bucket = System.get_env("MINIO_BUCKET")
      prefix = "system/backups/#{backup.id}/"
      test_pid = self()

      stub_cmds()

      # Listing the app bucket yields the object to mirror; listing the
      # backup-bucket prefix (during superseded cleanup) yields the parts.
      stub(ExAwsMock, :stream!, fn %ExAws.Operation.S3{bucket: bucket} ->
        if bucket == app_bucket do
          [%{key: "organisations/org1/file.pdf"}]
        else
          [%{key: prefix <> "database.dump"}, %{key: prefix <> "bucket.tar"}]
        end
      end)

      stub(ExAwsMock, :request, fn
        %ExAws.S3.Download{} ->
          {:ok, :done}

        # When the last part (manifest) is uploaded, simulate a competing
        # reconcile flipping the row to failed before publish.
        %ExAws.S3.Upload{path: path} ->
          if path && String.ends_with?(path, "manifest.json") do
            {:ok, _} =
              SystemBackups.mark_failed(SystemBackups.get_backup(backup.id), "reconciled")
          end

          {:ok, %{}}

        %ExAws.Operation.S3{http_method: :head, path: path} ->
          size = if String.ends_with?(path, "database.dump"), do: dump_size(), else: tar_size()
          {:ok, %{headers: [{"Content-Length", to_string(size)}]}}

        %ExAws.Operation.S3{http_method: :delete, path: path} ->
          send(test_pid, {:artifact_deleted, path})
          {:ok, %{}}
      end)

      assert {:error, :superseded} =
               perform_job(SystemBackupWorker, %{"backup_id" => backup.id})

      assert SystemBackups.get_backup(backup.id).status == :failed
      assert_received {:artifact_deleted, path}
      assert path =~ "system/backups/#{backup.id}/"
    end

    test "unknown backup_id fails cleanly" do
      assert {:error, _} =
               perform_job(SystemBackupWorker, %{"backup_id" => Faker.UUID.v4()})
    end
  end
end
