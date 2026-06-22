defmodule WraftDoc.Workers.SystemBackupScheduleWorkerTest do
  use WraftDoc.DataCase, async: false

  import WraftDoc.BackupStubs

  alias WraftDoc.SystemBackups
  alias WraftDoc.Workers.SystemBackupScheduleWorker

  setup do
    put_backup_config()
    :ok
  end

  test "reconciles an orphaned in-flight backup so it can't wedge the single-active index" do
    # A row whose heartbeat is older than the staleness window (a crashed run).
    stale = DateTime.utc_now() |> DateTime.add(-700, :second) |> DateTime.truncate(:second)

    backup =
      insert(:system_backup,
        status: :running,
        heartbeat_at: stale,
        started_at: stale,
        completed_at: nil,
        file_path: nil
      )

    assert {:ok, _} = perform_job(SystemBackupScheduleWorker, %{})

    failed = SystemBackups.get_backup(backup.id)
    assert failed.status == :failed
    assert failed.error =~ "orphaned"
  end

  test "leaves a fresh in-flight backup untouched" do
    backup = insert(:system_backup, status: :running, completed_at: nil)

    assert {:ok, _} = perform_job(SystemBackupScheduleWorker, %{})

    assert SystemBackups.get_backup(backup.id).status == :running
  end

  test "also reconciles an orphaned in-flight restore" do
    backup = insert(:system_backup, status: :completed)

    stale =
      DateTime.utc_now() |> DateTime.add(-60 * 60 * 8, :second) |> DateTime.truncate(:second)

    restore =
      insert(:system_backup_restore,
        backup: backup,
        status: :running,
        started_at: stale,
        completed_at: nil
      )

    assert {:ok, _} = perform_job(SystemBackupScheduleWorker, %{})

    assert SystemBackups.get_restore(restore.id).status == :failed
  end
end
