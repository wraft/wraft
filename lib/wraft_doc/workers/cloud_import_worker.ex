defmodule WraftDoc.Workers.CloudImportWorker do
  @moduledoc """
  Oban worker for handling Google Drive operations in the background.
  Supports downloading and exporting files from Google Drive.
  Can handle single file IDs or lists of file IDs.
  Can store files locally or in MinIO Storages.
  """

  use Oban.Worker, queue: :cloud_provider, max_attempts: 3
  require Logger

  alias WraftDoc.Storages
  alias WraftDoc.Storages.StorageItems

  @impl Oban.Worker
  def perform(%Oban.Job{
        args:
          %{
            "storage_item_ids" => storage_item_ids
          } = _args
      }) do
    results =
      storage_item_ids
      |> Enum.map(&StorageItems.get_storage_item!/1)
      |> Enum.map(fn storage_item ->
        Storages.download_and_upload_to_repo(storage_item)
      end)

    {:ok, results}
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    Logger.error("Invalid job arguments: #{inspect(args)}")
    {:error, "Invalid job arguments"}
  end
end
