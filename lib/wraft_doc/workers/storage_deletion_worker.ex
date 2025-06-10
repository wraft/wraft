defmodule WraftDoc.Workers.StorageDeletionWorker do
  use Oban.Worker, queue: :storage

  require Logger
  alias WraftDoc.Repo
  alias WraftDoc.Storage.StorageItem
  import Ecto.Query

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"folder_id" => folder_id}}) do
    Logger.info("Starting recursive deletion of folder", %{folder_id: folder_id})

    # Get all children of the folder
    children = from(s in StorageItem,
      where: s.parent_id == ^folder_id and s.is_deleted == false
    ) |> Repo.all()

    # Mark each child as deleted and schedule its asset deletion
    Enum.each(children, fn child ->
      # Mark child as deleted
      child
      |> StorageItem.changeset(%{
        is_deleted: true,
        deleted_at: DateTime.utc_now()
      })
      |> Repo.update()

      # If child is a folder, schedule its deletion
      if child.mime_type == "inode/directory" do
        %{folder_id: child.id}
        |> __MODULE__.new()
        |> Oban.insert()
      end

      # Schedule asset deletion for the child
      %{storage_item_id: child.id}
      |> WraftDoc.Workers.StorageAssetDeletionWorker.new()
      |> Oban.insert()
    end)

    :ok
  end
end
