defmodule WraftDoc.Workers.StorageDeletionWorker do
  @moduledoc """
  #   Worker for recursively deleting a folder and its contents in the storage system.
  """
  use Oban.Worker, queue: :storage

  require Logger
  alias WraftDoc.Repo
  alias WraftDoc.Storages.StorageItem
  import Ecto.Query

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"folder_id" => folder_id}}) do
    Logger.info("Starting recursive deletion of folder", %{folder_id: folder_id})

    children =
      StorageItem
      |> where([s], s.parent_id == ^folder_id and s.is_deleted == false)
      |> Repo.all()

    Enum.each(children, &process_child/1)

    :ok
  end

  defp process_child(%StorageItem{} = child) do
    # Wrap update and scheduling into transaction for safety
    Repo.transaction(fn ->
      # Mark child as deleted
      child
      |> StorageItem.changeset(%{
        is_deleted: true,
        deleted_at: DateTime.utc_now()
      })
      |> Repo.update!()

      case child.mime_type do
        "inode/directory" ->
          %{folder_id: child.id}
          |> __MODULE__.new()
          |> Oban.insert!()

        _ ->
          :ok
      end

      # Always schedule asset deletion
      %{storage_item_id: child.id}
      |> WraftDoc.Workers.StorageAssetDeletionWorker.new()
      |> Oban.insert!()
    end)
  end
end
