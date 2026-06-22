defmodule WraftDoc.Workers.SystemBackupWorker do
  @moduledoc """
  Runs a whole-application backup (see `WraftDoc.SystemBackups.BackupEngine`).

  Concurrency notes (these are load-bearing, do not "fix" them):

    * `max_attempts: 1` — with attempts remaining, `Oban.Plugins.Lifeline`
      (rescue_after: 5 min, purely time-based) would re-run a genuinely
      executing long backup *concurrently* with the still-live first run.
      One attempt + an explicit `failed` row is preferred.
    * Oban uniqueness below is best-effort UX dedup only. At minute 5,
      Lifeline flips the executing job to `discarded`, after which
      uniqueness no longer sees it. The authoritative single-in-flight
      guard is the partial unique index on `system_backups`; liveness is
      the heartbeat column, refreshed by an independent timer here (a
      single engine step can run far longer than any between-steps
      callback would fire).

  Two argument shapes: manual triggers carry a pre-created `backup_id`
  (row inserted by `SystemBackups.trigger_manual/1` before enqueue);
  cron fires carry only `trigger_type=scheduled` and the worker creates
  the pending row itself, treating an index conflict as a logged no-op.
  """

  use Oban.Worker,
    queue: :backups,
    max_attempts: 1,
    unique: [period: :infinity, states: [:available, :scheduled, :executing, :retryable]]

  require Logger

  alias WraftDoc.SystemBackups
  alias WraftDoc.SystemBackups.BackupEngine

  @heartbeat_interval :timer.minutes(1)

  # A whole-app dump + bucket mirror is expected to take hours at
  # production scale.
  @impl Oban.Worker
  def timeout(_job), do: :timer.hours(6)

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    # First step of EVERY execution, manual or scheduled: flip orphaned
    # (stale-heartbeat) running rows to failed so a crashed run cannot
    # block backups forever.
    SystemBackups.reconcile_stale()

    if SystemBackups.enabled?() do
      args |> resolve_backup() |> run()
    else
      Logger.info("system backup skipped: feature flag is off")
      {:ok, :disabled}
    end
  end

  defp resolve_backup(%{"backup_id" => backup_id}) do
    case SystemBackups.get_backup(backup_id) do
      nil -> {:error, "backup row #{backup_id} not found"}
      backup -> {:ok, backup}
    end
  end

  defp resolve_backup(%{"trigger_type" => "scheduled"}) do
    SystemBackups.create_pending(:scheduled)
  end

  defp resolve_backup(args), do: {:error, "invalid job arguments: #{inspect(args)}"}

  defp run({:error, :backup_in_progress}) do
    Logger.info("system backup skipped: a backup is already in progress")
    {:ok, :skipped}
  end

  defp run({:error, reason}) do
    Logger.error("system backup not started: #{inspect(reason)}")
    {:error, reason}
  end

  defp run({:ok, backup}) do
    case SystemBackups.mark_running(backup) do
      {:ok, running} -> execute(running)
      {:error, _changeset} -> {:error, "could not mark backup running"}
    end
  end

  defp execute(backup) do
    heartbeat_pid = start_heartbeat(backup.id)

    try do
      case BackupEngine.build(backup) do
        {:ok, result} -> publish(backup, result)
        {:error, reason} -> fail(backup, reason)
      end
    rescue
      error ->
        SystemBackups.mark_failed(backup, Exception.message(error))
        reraise error, __STACKTRACE__
    after
      stop_heartbeat(heartbeat_pid)
    end
  end

  defp publish(backup, result) do
    case SystemBackups.mark_completed(backup, result) do
      {:ok, _completed} ->
        SystemBackups.schedule_retention()
        {:ok, :completed}

      {:error, :not_running} ->
        # The row was reconciled to failed mid-run (stale heartbeat —
        # e.g. the node hung long enough for another run to reconcile
        # us). Never resurrect; never leave an orphan artifact that
        # row-driven retention can't see.
        Logger.error(
          "system backup #{backup.id} finished but its row was reconciled to failed; " <>
            "deleting the uploaded artifact #{result.file_path}"
        )

        case SystemBackups.delete_prefix(result.file_path) do
          :ok ->
            :ok

          {:error, reason} ->
            # Artifact leaked: object exists but the row is failed, so
            # retention can't see it. Surface loudly for the orphan sweep.
            Logger.error(
              "system backup #{backup.id}: failed to delete superseded artifact " <>
                "#{result.file_path}: #{inspect(reason)}"
            )
        end

        {:error, :superseded}
    end
  end

  defp fail(backup, reason) do
    SystemBackups.mark_failed(backup, reason)
    Logger.error("system backup #{backup.id} failed: #{reason}")
    {:error, reason}
  end

  # The heartbeat runs in a linked process on its own timer, independent
  # of engine step boundaries. Linked on purpose: if the worker dies, the
  # heartbeat dies with it, the row goes stale, and reconcile flips it to
  # failed — exactly the recovery path we want.
  defp start_heartbeat(backup_id) do
    {:ok, pid} =
      Task.start_link(fn ->
        heartbeat_loop(backup_id)
      end)

    pid
  end

  defp heartbeat_loop(backup_id) do
    Process.sleep(@heartbeat_interval)

    # A transient DB error here must NOT take the multi-hour backup down
    # through the link — log and keep beating; a genuinely dead row stops
    # the loop via the :error return below.
    result =
      try do
        SystemBackups.heartbeat(backup_id)
      rescue
        error ->
          Logger.warning(
            "system backup #{backup_id}: heartbeat update failed, continuing: " <>
              Exception.message(error)
          )

          :ok
      end

    case result do
      # Row is no longer running (completed/reconciled) — stop quietly.
      :error -> :ok
      :ok -> heartbeat_loop(backup_id)
    end
  end

  defp stop_heartbeat(pid) do
    Process.unlink(pid)
    Process.exit(pid, :kill)
  end
end
