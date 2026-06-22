defmodule WraftDoc.SystemBackupsTest do
  use WraftDoc.DataCase, async: false

  import WraftDoc.BackupStubs

  alias WraftDoc.SystemBackups
  alias WraftDoc.SystemBackups.Backup

  describe "schedule" do
    setup do
      put_backup_config(enabled: true)
      :ok
    end

    test "get_schedule creates a default singleton, update_schedule edits it" do
      schedule = SystemBackups.get_schedule()
      assert schedule.enabled == false
      assert schedule.frequency == :daily

      {:ok, updated} =
        SystemBackups.update_schedule(%{
          "enabled" => "true",
          "frequency" => "weekly",
          "hour" => "2",
          "minute" => "15",
          "day_of_week" => "3",
          "retention_count" => "10"
        })

      assert updated.enabled
      assert updated.frequency == :weekly
      assert updated.hour == 2
      assert updated.retention_count == 10
      # Still a singleton.
      assert SystemBackups.get_schedule().id == schedule.id
      assert SystemBackups.retention_count() == 10
    end

    test "maybe_run_scheduled does nothing when disabled" do
      {:ok, _} = SystemBackups.update_schedule(%{"enabled" => "false"})
      assert SystemBackups.maybe_run_scheduled() == :not_due
      assert SystemBackups.completed_count() == 0
      refute SystemBackups.in_flight?()
    end

    test "maybe_run_scheduled enqueues once when due, then is idempotent for the day" do
      {:ok, _} =
        SystemBackups.update_schedule(%{
          "enabled" => "true",
          "frequency" => "daily",
          "hour" => "1",
          "minute" => "0"
        })

      at = ~U[2026-06-10 01:30:00Z]
      assert SystemBackups.maybe_run_scheduled(at) == :enqueued
      assert SystemBackups.in_flight?()

      # Same period: already ran -> not due again.
      assert SystemBackups.maybe_run_scheduled(~U[2026-06-10 02:00:00Z]) == :not_due
    end

    test "maybe_run_scheduled is not due before the configured time" do
      {:ok, _} =
        SystemBackups.update_schedule(%{"enabled" => "true", "hour" => "3", "minute" => "0"})

      assert SystemBackups.maybe_run_scheduled(~U[2026-06-10 02:59:00Z]) == :not_due
    end

    test "maybe_run_scheduled does not consume the period when a backup is in flight" do
      {:ok, _} =
        SystemBackups.update_schedule(%{
          "enabled" => "true",
          "frequency" => "daily",
          "hour" => "1",
          "minute" => "0"
        })

      # A manual backup is already running at the scheduled time.
      {:ok, _pending} = SystemBackups.create_pending(:manual, insert(:internal_user))

      assert SystemBackups.maybe_run_scheduled(~U[2026-06-10 01:30:00Z]) == :not_due
      # last_run_on was NOT stamped, so once the manual backup clears the
      # scheduled run still fires this period — no silently-skipped day.
      assert SystemBackups.get_schedule().last_run_on == nil
    end

    test "weekly schedule only runs on the configured day" do
      # 2026-06-10 is a Wednesday (day_of_week 3).
      {:ok, _} =
        SystemBackups.update_schedule(%{
          "enabled" => "true",
          "frequency" => "weekly",
          "day_of_week" => "1",
          "hour" => "1",
          "minute" => "0"
        })

      assert SystemBackups.maybe_run_scheduled(~U[2026-06-10 01:30:00Z]) == :not_due

      {:ok, _} = SystemBackups.update_schedule(%{"day_of_week" => "3"})
      assert SystemBackups.maybe_run_scheduled(~U[2026-06-10 01:30:00Z]) == :enqueued
    end
  end

  describe "create_pending/2" do
    test "inserts a pending manual backup with the creator recorded" do
      admin = insert(:internal_user)

      assert {:ok, %Backup{} = backup} = SystemBackups.create_pending(:manual, admin)
      assert backup.status == :pending
      assert backup.trigger_type == :manual
      assert backup.creator_id == admin.id
    end

    test "inserts a scheduled backup with no creator (System actor)" do
      assert {:ok, %Backup{} = backup} = SystemBackups.create_pending(:scheduled)
      assert backup.trigger_type == :scheduled
      assert backup.creator_id == nil
    end

    test "rejects a second backup while one is pending" do
      assert {:ok, _} = SystemBackups.create_pending(:scheduled)
      assert {:error, :backup_in_progress} = SystemBackups.create_pending(:scheduled)
    end

    test "rejects a second backup while one is running" do
      {:ok, backup} = SystemBackups.create_pending(:scheduled)
      {:ok, _} = SystemBackups.mark_running(backup)

      assert {:error, :backup_in_progress} = SystemBackups.create_pending(:scheduled)
    end

    test "two concurrent inserts race: exactly one wins via the unique index" do
      results =
        1..2
        |> Enum.map(fn _i ->
          Task.async(fn -> SystemBackups.create_pending(:scheduled) end)
        end)
        |> Task.await_many()

      assert Enum.count(results, &match?({:ok, _}, &1)) == 1
      assert Enum.count(results, &match?({:error, :backup_in_progress}, &1)) == 1
    end

    test "no manual cooldown by default — back-to-back manual backups allowed" do
      admin = insert(:internal_user)

      {:ok, backup} = SystemBackups.create_pending(:manual, admin)
      {:ok, running} = SystemBackups.mark_running(backup)
      {:ok, _} = SystemBackups.mark_completed(running, %{file_path: "k", file_size: 1})

      assert {:ok, _} = SystemBackups.create_pending(:manual, admin)
    end

    test "manual trigger inside a configured cooldown window is rejected" do
      admin = insert(:internal_user)
      {:ok, _} = SystemBackups.update_schedule(%{"manual_cooldown_minutes" => "60"})

      {:ok, backup} = SystemBackups.create_pending(:manual, admin)
      {:ok, running} = SystemBackups.mark_running(backup)
      {:ok, _} = SystemBackups.mark_completed(running, %{file_path: "k", file_size: 1})

      assert {:error, :cooldown} = SystemBackups.create_pending(:manual, admin)
    end

    test "a failed manual backup does not block an immediate retry (with cooldown set)" do
      admin = insert(:internal_user)
      {:ok, _} = SystemBackups.update_schedule(%{"manual_cooldown_minutes" => "60"})

      {:ok, backup} = SystemBackups.create_pending(:manual, admin)
      {:ok, _} = SystemBackups.mark_failed(backup, "boom")

      assert {:ok, _} = SystemBackups.create_pending(:manual, admin)
    end

    test "scheduled triggers are exempt from the manual cooldown" do
      admin = insert(:internal_user)
      {:ok, _} = SystemBackups.update_schedule(%{"manual_cooldown_minutes" => "60"})

      {:ok, backup} = SystemBackups.create_pending(:manual, admin)
      {:ok, running} = SystemBackups.mark_running(backup)
      {:ok, _} = SystemBackups.mark_completed(running, %{file_path: "k", file_size: 1})

      assert {:ok, _} = SystemBackups.create_pending(:scheduled)
    end
  end

  describe "lifecycle transitions" do
    test "mark_running sets started_at and a fresh heartbeat" do
      {:ok, backup} = SystemBackups.create_pending(:scheduled)

      assert {:ok, running} = SystemBackups.mark_running(backup)
      assert running.status == :running
      assert running.started_at
      assert running.heartbeat_at
    end

    test "heartbeat/1 bumps heartbeat_at on a running backup" do
      {:ok, backup} = SystemBackups.create_pending(:scheduled)
      {:ok, running} = SystemBackups.mark_running(backup)

      stale = DateTime.truncate(DateTime.add(DateTime.utc_now(), -300, :second), :second)
      {:ok, _} = running |> Backup.update_changeset(%{heartbeat_at: stale}) |> Repo.update()

      assert :ok = SystemBackups.heartbeat(running.id)

      fresh = SystemBackups.get_backup(running.id)
      assert DateTime.compare(fresh.heartbeat_at, stale) == :gt
    end

    test "heartbeat/1 returns :error for a non-running backup" do
      {:ok, backup} = SystemBackups.create_pending(:scheduled)

      assert :error = SystemBackups.heartbeat(backup.id)
    end

    test "mark_completed publishes per-part sizes, checksums, and manifest" do
      {:ok, backup} = SystemBackups.create_pending(:scheduled)
      {:ok, running} = SystemBackups.mark_running(backup)

      assert {:ok, completed} =
               SystemBackups.mark_completed(running, %{
                 file_path: "system/backups/x/",
                 file_size: 42,
                 db_size: 30,
                 db_checksum: "db-abc",
                 bucket_size: 12,
                 bucket_checksum: "bk-def",
                 manifest: %{"object_count" => 3}
               })

      assert completed.status == :completed
      assert completed.file_size == 42
      assert completed.db_size == 30
      assert completed.bucket_size == 12
      assert completed.db_checksum == "db-abc"
      assert completed.completed_at
    end

    test "mark_completed refuses when the row was reconciled to failed mid-run" do
      {:ok, backup} = SystemBackups.create_pending(:scheduled)
      {:ok, running} = SystemBackups.mark_running(backup)
      {:ok, _} = SystemBackups.mark_failed(running, "reconciled")

      assert {:error, :not_running} =
               SystemBackups.mark_completed(running, %{file_path: "k", file_size: 1})
    end

    test "mark_failed records a truncated error" do
      {:ok, backup} = SystemBackups.create_pending(:scheduled)

      long_error = String.duplicate("x", 5_000)
      assert {:ok, failed} = SystemBackups.mark_failed(backup, long_error)
      assert failed.status == :failed
      assert String.length(failed.error) == 2_000
    end
  end

  describe "reconcile_stale/0" do
    test "flips a running row with a stale heartbeat to failed" do
      {:ok, backup} = SystemBackups.create_pending(:scheduled)
      {:ok, running} = SystemBackups.mark_running(backup)

      stale =
        DateTime.utc_now()
        |> DateTime.add(-SystemBackups.heartbeat_staleness_seconds() - 60, :second)
        |> DateTime.truncate(:second)

      {:ok, _} = running |> Backup.update_changeset(%{heartbeat_at: stale}) |> Repo.update()

      assert SystemBackups.reconcile_stale() == 1
      assert SystemBackups.get_backup(running.id).status == :failed
    end

    test "leaves a running row with a fresh heartbeat untouched" do
      {:ok, backup} = SystemBackups.create_pending(:scheduled)
      {:ok, running} = SystemBackups.mark_running(backup)

      assert SystemBackups.reconcile_stale() == 0
      assert SystemBackups.get_backup(running.id).status == :running
    end

    test "never touches completed or deleted rows" do
      completed = insert(:system_backup, status: :completed)
      deleted = insert(:system_backup, status: :deleted)

      assert SystemBackups.reconcile_stale() == 0
      assert SystemBackups.get_backup(completed.id).status == :completed
      assert SystemBackups.get_backup(deleted.id).status == :deleted
    end

    test "clears an orphaned pending row that never progressed (deadlock guard)" do
      # A worker that died (or was Lifeline-discarded) between create_pending
      # and mark_running leaves a heartbeat-less pending row that would wedge
      # the single-in-flight index forever if reconcile ignored it.
      stale =
        DateTime.utc_now()
        |> DateTime.add(-SystemBackups.heartbeat_staleness_seconds() - 60, :second)
        |> DateTime.truncate(:second)

      pending =
        insert(:system_backup, status: :pending, heartbeat_at: nil, inserted_at: stale)

      assert SystemBackups.reconcile_stale() == 1
      assert SystemBackups.get_backup(pending.id).status == :failed
      # The index slot is freed: a new backup can now start.
      assert {:ok, _} = SystemBackups.create_pending(:scheduled)
    end

    test "leaves a fresh pending row (just enqueued) untouched" do
      {:ok, pending} = SystemBackups.create_pending(:scheduled)

      assert SystemBackups.reconcile_stale() == 0
      assert SystemBackups.get_backup(pending.id).status == :pending
    end
  end

  describe "prunable/1" do
    test "returns only completed rows beyond the newest N" do
      backups =
        for i <- 1..9 do
          insert(:system_backup,
            status: :completed,
            inserted_at: DateTime.add(DateTime.utc_now(), -i * 60, :second)
          )
        end

      prunable = SystemBackups.prunable(7)
      prunable_ids = Enum.map(prunable, & &1.id)

      assert length(prunable) == 2
      # The two oldest of the nine.
      assert Enum.at(backups, 7).id in prunable_ids
      assert Enum.at(backups, 8).id in prunable_ids
    end

    test "counts manual and scheduled in a single pool" do
      for i <- 1..3 do
        insert(:system_backup,
          status: :completed,
          trigger_type: :manual,
          inserted_at: DateTime.add(DateTime.utc_now(), -i * 60, :second)
        )
      end

      for i <- 4..6 do
        insert(:system_backup,
          status: :completed,
          trigger_type: :scheduled,
          inserted_at: DateTime.add(DateTime.utc_now(), -i * 60, :second)
        )
      end

      assert length(SystemBackups.prunable(4)) == 2
    end

    test "never returns pending or running rows" do
      {:ok, backup} = SystemBackups.create_pending(:scheduled)
      {:ok, _} = SystemBackups.mark_running(backup)

      assert SystemBackups.prunable(0) == []
    end
  end
end
