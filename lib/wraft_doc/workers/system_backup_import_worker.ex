defmodule WraftDoc.Workers.SystemBackupImportWorker do
  @moduledoc """
  Imports a backup uploaded by an admin: extracts the Full archive — a zip
  (current) or tar (older backups) of database.dump + bucket.tar +
  manifest.json — uploads the parts under a
  new backup prefix, and marks the row completed. The result behaves like
  any backup (download / restore).

  `max_attempts: 1` — the staged upload is deleted after the run, so a
  retry would have nothing to read.
  """
  use Oban.Worker, queue: :backups, max_attempts: 1

  require Logger

  alias WraftDoc.SystemBackups
  alias WraftDoc.SystemBackups.Archive
  alias WraftDoc.SystemBackups.BackupEngine

  @impl Oban.Worker
  def timeout(_job), do: :timer.hours(2)

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"backup_id" => id, "tar_path" => tar_path}}) do
    case SystemBackups.get_backup(id) do
      nil ->
        File.rm(tar_path)
        {:error, "backup row #{id} not found"}

      backup ->
        run(backup, tar_path)
    end
  end

  defp run(backup, tar_path) do
    case SystemBackups.mark_running(backup) do
      {:ok, running} ->
        import_running(running, tar_path)

      {:error, reason} ->
        # A transient DB error marking the row running must not crash the job
        # (a MatchError would bypass mark_failed and leave the row pending,
        # wedging the single-active index until reconcile_stale fires).
        File.rm(tar_path)
        SystemBackups.mark_failed(backup, "could not start import: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp import_running(running, tar_path) do
    case import_parts(running, tar_path) do
      {:ok, result} ->
        finish_import(running, result)

      {:error, reason} ->
        SystemBackups.mark_failed(running, reason)
        Logger.error("import of backup #{running.id} failed: #{reason}")
        {:error, reason}
    end
  rescue
    error ->
      SystemBackups.mark_failed(running, Exception.message(error))
      reraise error, __STACKTRACE__
  after
    File.rm(tar_path)
  end

  defp finish_import(running, result) do
    case SystemBackups.mark_completed(running, result) do
      {:ok, _} ->
        Logger.info("imported backup #{running.id}")
        {:ok, :imported}

      {:error, reason} ->
        # The row was reconciled to failed mid-run, or the update errored.
        # Never resurrect; delete the just-uploaded parts so the artifact
        # isn't orphaned (retention only sees completed rows).
        BackupEngine.delete_prefix(result.file_path)

        Logger.error(
          "import of #{running.id}: mark_completed failed (#{inspect(reason)}); artifact deleted"
        )

        {:error, reason}
    end
  end

  defp import_parts(backup, archive_path) do
    staging = Briefly.create!(directory: true)

    try do
      with {_out, 0} <- Archive.extract(archive_path, staging),
           :ok <- require_file(Path.join(staging, "database.dump")),
           prefix = BackupEngine.backup_prefix(backup),
           {:ok, db_size} <- upload(staging, prefix, "database.dump"),
           {:ok, bucket_size} <- upload_optional(staging, prefix, "bucket.tar"),
           {:ok, _} <- upload_optional(staging, prefix, "manifest.json") do
        {:ok,
         %{
           file_path: prefix,
           file_size: db_size + bucket_size,
           db_size: db_size,
           bucket_size: bucket_size,
           manifest: %{"imported" => true}
         }}
      else
        {output, status} when is_binary(output) ->
          {:error, "archive extract failed (exit #{status})"}

        other ->
          other
      end
    after
      File.rm_rf(staging)
    end
  end

  defp require_file(path) do
    if File.regular?(path), do: :ok, else: {:error, "uploaded archive is missing database.dump"}
  end

  defp upload(staging, prefix, name) do
    BackupEngine.put_file(Path.join(staging, name), prefix <> name)
  end

  defp upload_optional(staging, prefix, name) do
    path = Path.join(staging, name)
    if File.regular?(path), do: upload(staging, prefix, name), else: {:ok, 0}
  end
end
