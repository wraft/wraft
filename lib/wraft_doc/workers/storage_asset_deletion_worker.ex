defmodule WraftDoc.Workers.StorageAssetDeletionWorker do
  use Oban.Worker, queue: :storage

  require Logger
  alias WraftDoc.Repo
  alias WraftDoc.Storage.StorageAsset
  import Ecto.Query

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"storage_item_id" => storage_item_id}}) do
    Logger.info("Starting asset deletion for storage item", %{storage_item_id: storage_item_id})

    # Get all assets for the storage item
    assets = from(sa in StorageAsset,
      where: sa.storage_item_id == ^storage_item_id
    ) |> Repo.all()

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
