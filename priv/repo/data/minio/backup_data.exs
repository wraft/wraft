defmodule WraftDoc.Minio.BackupData do
  @moduledoc """
  Backup the existing files in the object storage to a new bucket

  mix run priv/repo/data/minio/backup_data.exs
  """
  require Logger
  alias WraftDoc.Minio.Utils

  @wraft_target_bucket "wraft"
  @wraft_source_bucket "wraft-remote"

  # Create a temporary bucket by name wraft-temp
  Logger.info("Creating bucket #{@wraft_target_bucket}")

  Utils.create_bucket(@wraft_target_bucket)

  Logger.info("Bucket #{@wraft_target_bucket} created")

  # Move all files from wraft source bucket to target bucket
  Logger.info("Moving files from #{@wraft_source_bucket} to #{@wraft_target_bucket}")

  @wraft_source_bucket
  |> Utils.list_files("")
  |> Enum.map(fn file_path ->
    Task.async(fn ->
      Logger.info("Moving file #{file_path}")

      if Utils.copy_files(@wraft_source_bucket, file_path, @wraft_target_bucket, file_path) do
        Logger.info("File #{file_path} moved")
      else
        Logger.error("File #{file_path} failed to move by efficient way")
        Logger.info("retrying ...")

        Utils.download_locally_and_upload(
          @wraft_source_bucket,
          file_path,
          @wraft_target_bucket,
          Utils.format(file_path)
        )

        Logger.info("File #{file_path} moved")
      end
    end)
  end)
  # Process in chunks of 20
  |> Enum.chunk_every(20)
  |> Enum.each(&Task.await_many(&1, :infinity))
end
