defmodule WraftDoc.Workers.SystemBackupRetentionWorker do
  @moduledoc """
  Prunes completed system backups to the newest N (single pool, manual
  and scheduled together — the schedule's configurable manual cooldown
  (`manual_cooldown_minutes`, default 0 = no limit) is what bounds
  manual-trigger churn).

  Runs as a separate job so a prune failure never fails the backup that
  enqueued it. Delete-after-verify: prunes only while at least one newer
  completed backup remains, deletes the exact object key (direct
  `S3.delete_object`, never a prefix listing), then soft-deletes the row
  and logs a retention audit line. One delete failure doesn't abort the
  rest.
  """

  use Oban.Worker, queue: :backups, max_attempts: 3

  require Logger

  alias WraftDoc.SystemBackups

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    keep = SystemBackups.retention_count()
    prunable = SystemBackups.prunable(keep)

    Enum.each(prunable, &prune/1)

    {:ok, %{pruned: length(prunable)}}
  end

  defp prune(backup) do
    with :ok <- SystemBackups.delete_prefix(backup.file_path),
         {:ok, _} <- SystemBackups.mark_deleted(backup) do
      Logger.info(
        "retention: deleted system backup #{backup.id} " <>
          "(#{backup.file_path}) — actor=System"
      )
    else
      {:error, reason} ->
        # Leave the row completed so a later run retries; never abort
        # pruning the remaining candidates. (Object delete is idempotent,
        # so a retry after a mark_deleted failure is safe.)
        Logger.error("retention: could not fully prune backup #{backup.id}: #{inspect(reason)}")
    end
  end
end
