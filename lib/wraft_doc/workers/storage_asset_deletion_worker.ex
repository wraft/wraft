defmodule WraftDoc.Workers.StorageAssetDeletionWorker do
  @moduledoc """
  Handles the deletion of storage assets associated with a specific storage item.
  This worker is responsible for marking assets as deleted in the database.
  It does not handle the actual file deletion, which is managed by a separate process.
  """
  use Oban.Worker, queue: :storage

  require Logger
  alias WraftDoc.Repo
  alias WraftDoc.Storage.StorageAsset
  import Ecto.Query

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"storage_item_id" => storage_item_id}}) do
    Logger.info("Starting asset deletion for storage item", %{storage_item_id: storage_item_id})

    # Get all assets for the storage item
    assets =
      from(sa in StorageAsset,
        where: sa.storage_item_id == ^storage_item_id
      )

    Repo.all(assets)

    # Mark each asset for deletion (actual file deletion will be handled by a separate process)
    Enum.each(assets, fn asset ->
      asset
      |> StorageAsset.changeset(%{
        processing_status: "deleted",
        upload_completed_at: DateTime.utc_now()
      })
      |> Repo.update()
    end)

    :ok
  end
end
