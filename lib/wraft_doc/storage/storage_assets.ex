# defmodule WraftDoc.Storage.Assets do
#   @moduledoc """
#   Storage assets, repositories, and upload management - handles file uploads,
#   storage assets, repositories, access logs, and sync jobs.
#   """

#   import Ecto.Query, warn: false
#   alias WraftDoc.Repo
#   alias WraftDoc.Storage.{Repository, StorageAsset, StorageItem, AccessLog, SyncJob}

#   def list_storage_assets do
#     Repo.all(StorageAsset)
#   end

#   def get_storage_asset!(id), do: Repo.get!(StorageAsset, id)

#   def create_storage_asset(attrs \\ %{}) do
#     %StorageAsset{}
#     |> StorageAsset.changeset(attrs)
#     |> Repo.insert()
#   end

#   def update_storage_asset(%StorageAsset{} = storage_asset, attrs) do
#     storage_asset
#     |> StorageAsset.changeset(attrs)
#     |> Repo.update()
#   end

#   def delete_storage_asset(%StorageAsset{} = storage_asset) do
#     Repo.delete(storage_asset)
#   end

#   def change_storage_asset(%StorageAsset{} = storage_asset, attrs \\ %{}) do
#     StorageAsset.changeset(storage_asset, attrs)
#   end

#     def schedule_asset_deletion(storage_item_id) do
#     %{storage_item_id: storage_item_id}
#     |> WraftDoc.Workers.StorageAssetDeletionWorker.new()
#     |> Oban.insert()
#   end

#    def get_storage_asset_by_org(id, organisation_id) do
#     from(s in StorageAsset,
#       where: s.id == ^id,
#       where: s.organisation_id == ^organisation_id
#     )
#     |> Repo.one()
#   end

#   def list_storage_assets_by_organisation(organisation_id) do
#     from(s in StorageAsset,
#       where: s.organisation_id == ^organisation_id,
#       order_by: [desc: s.inserted_at]
#     )
#     |> Repo.all()
#   end

#   def get_storage_assets_for_item(storage_item_id) do
#     from(sa in StorageAsset,
#       where: sa.storage_item_id == ^storage_item_id,
#       order_by: [desc: sa.inserted_at]
#     )
#     |> Repo.all()
#   end
# end
defmodule WraftDoc.Storage.StorageAssets do
  @moduledoc """
  Handles storage assets, repositories, access logs, and sync jobs.

  Provides functions for managing file uploads, querying assets,
  and scheduling asset deletions.
  """

  import Ecto.Query, warn: false

  alias WraftDoc.Repo
  alias WraftDoc.Storage.StorageAsset
  alias WraftDoc.Workers.StorageAssetDeletionWorker

  # alias WraftDoc.Storage.AccessLog
  # alias WraftDoc.Storage.Repository

  # alias WraftDoc.Storage.StorageItem
  # alias WraftDoc.Storage.SyncJob

  def list_storage_assets do
    Repo.all(StorageAsset)
  end

  def get_storage_asset!(id) do
    Repo.get!(StorageAsset, id)
  end

  def create_storage_asset(attrs \\ %{}) do
    %StorageAsset{}
    |> StorageAsset.changeset(attrs)
    |> Repo.insert()
  end

  def update_storage_asset(%StorageAsset{} = storage_asset, attrs) do
    storage_asset
    |> StorageAsset.changeset(attrs)
    |> Repo.update()
  end

  def delete_storage_asset(%StorageAsset{} = storage_asset) do
    Repo.delete(storage_asset)
  end

  def change_storage_asset(%StorageAsset{} = storage_asset, attrs \\ %{}) do
    StorageAsset.changeset(storage_asset, attrs)
  end

  def get_storage_asset_by_org(id, organisation_id) do
    StorageAsset
    |> where([s], s.id == ^id and s.organisation_id == ^organisation_id)
    |> Repo.one()
  end

  def list_storage_assets_by_organisation(organisation_id) do
    StorageAsset
    |> where([s], s.organisation_id == ^organisation_id)
    |> order_by([s], desc: s.inserted_at)
    |> Repo.all()
  end

  def get_storage_assets_for_item(storage_item_id) do
    StorageAsset
    |> where([sa], sa.storage_item_id == ^storage_item_id)
    |> order_by([sa], desc: sa.inserted_at)
    |> Repo.all()
  end

  # Builds parameters for storage asset creation
  def build_storage_asset_params(_params, file_metadata, upload, current_user, organisation_id) do
    storage_asset_params = %{
      filename: upload,
      storage_key: file_metadata.storage_key,
      # or "s3", "minio" based on config
      storage_backend: "local",
      file_size: file_metadata.file_size,
      checksum_sha256: file_metadata.checksum_sha256,
      mime_type: file_metadata.mime_type,
      processing_status: "pending",
      # Will be set after successful upload
      upload_completed_at: nil,
      creator_id: current_user && current_user.id,
      organisation_id: organisation_id
    }

    {:ok, storage_asset_params}
  end

  def schedule_asset_deletion(storage_item_id) do
    job = StorageAssetDeletionWorker.new(%{storage_item_id: storage_item_id})
    Oban.insert(job)
  end
end
