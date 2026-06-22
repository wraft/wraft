defmodule WraftDoc.Workers.SystemBackupScheduleWorker do
  @moduledoc """
  Periodic checker (every 15 minutes) for the UI-configurable auto-backup
  schedule. Reads the schedule from the DB and enqueues a scheduled backup
  when due — so enable/disable and timing changes take effect without a
  redeploy. The once-per-period guard lives in
  `SystemBackups.maybe_run_scheduled/1`. Also reconciles orphaned backups and
  restores so a crashed run can't wedge the single-active index permanently.
  The backup reconcile must live here (not only as the backup worker's first
  step) because a wedged in-flight row blocks `create_pending`, which is what
  enqueues the worker that would reconcile — so nothing else ever clears it.
  """
  use Oban.Worker, queue: :backups, max_attempts: 1

  alias WraftDoc.SystemBackups

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    SystemBackups.reconcile_stale()
    SystemBackups.reconcile_stale_restores()
    {:ok, SystemBackups.maybe_run_scheduled()}
  end
end
