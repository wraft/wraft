defmodule WraftDoc.Workers.SystemRestoreWorker do
  @moduledoc """
  Runs a restore of a backup into a NEW target database + bucket (see
  `WraftDoc.SystemBackups.RestoreEngine`). The live database and bucket
  are never touched. `max_attempts: 1` — a half-applied restore should be
  inspected, not blindly retried (the target DB/bucket may already exist).
  """
  use Oban.Worker, queue: :backups, max_attempts: 1

  require Logger

  alias WraftDoc.SystemBackups
  alias WraftDoc.SystemBackups.RestoreEngine

  @impl Oban.Worker
  def timeout(_job), do: :timer.hours(6)

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"restore_id" => restore_id}}) do
    case SystemBackups.get_restore(restore_id) do
      nil ->
        {:error, "restore #{restore_id} not found"}

      restore ->
        backup = restore.backup_id && SystemBackups.get_backup(restore.backup_id)
        run(restore, backup)
    end
  end

  def perform(%Oban.Job{args: args}) do
    Logger.error("invalid restore job args: #{inspect(args)}")
    {:error, "invalid job arguments"}
  end

  defp run(restore, nil) do
    SystemBackups.mark_restore_failed(restore, "source backup no longer exists")
    {:error, :backup_missing}
  end

  defp run(restore, backup) do
    case SystemBackups.mark_restore_running(restore) do
      {:error, reason} ->
        # Don't crash on a transient DB error (a MatchError would bypass
        # mark_restore_failed and leave the row stuck in pending).
        SystemBackups.mark_restore_failed(restore, "could not start restore: #{inspect(reason)}")
        {:error, reason}

      {:ok, restore} ->
        run_restore(restore, backup)
    end
  end

  defp run_restore(restore, backup) do
    Logger.info(
      "system restore #{restore.id}: restoring backup #{backup.id} into " <>
        "db=#{restore.target_database} bucket=#{restore.target_bucket}"
    )

    try do
      case RestoreEngine.run(restore, backup) do
        :ok ->
          SystemBackups.mark_restore_completed(restore)
          Logger.info("system restore #{restore.id} completed")
          {:ok, :restored}

        {:error, reason} ->
          SystemBackups.mark_restore_failed(restore, reason)
          Logger.error("system restore #{restore.id} failed: #{reason}")
          {:error, reason}
      end
    rescue
      error ->
        SystemBackups.mark_restore_failed(restore, Exception.message(error))
        reraise error, __STACKTRACE__
    end
  end
end
