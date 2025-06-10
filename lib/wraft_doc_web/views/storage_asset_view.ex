defmodule WraftDocWeb.Api.V1.StorageAssetView do
  use WraftDocWeb, :view
  alias WraftDoc.Storage.StorageAsset
  alias WraftDocWeb.StorageAssetUploader

  @doc """
  Renders a list of repository assets.
  """
  # def index(%{repository_assets: repository_assets}) do
  #   %{data: for(repository_asset <- repository_assets, do: data(repository_asset))}
  # end

  def render("index.json", %{storage_assets: storage_assets}) do
    %{data: render_many(storage_assets, __MODULE__, "file.json")}
  end

  @doc """
  Renders a single repository asset.
  """
  def show(%{storage_assets: storage_assets}) do
    %{data: data(storage_assets)}
  end

  def render("file.json", %{storage_asset: storage_asset}) do
    %{
      id: storage_asset.id,
      name: storage_asset.filename,
      # version: storage_asset.version,
      file_size: storage_asset.file_size,
      # is_deleted: storage_asset.is_deleted,
      # deleted_at: storage_asset.deleted_at,
      # repository_id: file.repository_id,
      inserted_at: storage_asset.inserted_at,
      updated_at: storage_asset.updated_at,
      mime_type: storage_asset.mime_type,
      # file_extension: storage_asset.file_extension,
      storage_key: storage_asset.storage_key,
      checksum_sha256: storage_asset.checksum_sha256,
      # content_extracted: storage_asset.content_extracted,
      # display_name: storage_asset.display_name,
      # download_count: storage_asset.download_count,
      # folder_id: storage_asset.folder_id,
      # last_accessed_at: storage_asset.last_accessed_at,
      # parent_version_id: storage_asset.parent_version_id,
      # thumbnail_generated: storage_asset.thumbnail_generated
    }
  end

  defp data(%StorageAsset{} = storage_asset) do
    %{
      id: storage_asset.id,
      filename: storage_asset.filename,
      file_size: storage_asset.file_size,
      mime_type: storage_asset.mime_type,
      storage_key: storage_asset.storage_key,
      checksum_sha256: storage_asset.checksum_sha256,
      processing_status: storage_asset.processing_status,
      # processed: storage_asset.processed,
      # content_extracted: storage_asset.content_extracted,
      # thumbnail_generated: storage_asset.thumbnail_generated,
      # download_count: storage_asset.download_count,
      # last_accessed_at: storage_asset.last_accessed_at,
      # metadata: storage_asset.metadata,
      # storage_item_id: storage_asset.storage_item_id,
      # organisation_id: storage_asset.organisation_id,
      # creator_id: storage_asset.creator_id,
      inserted_at: storage_asset.inserted_at,
      updated_at: storage_asset.updated_at,
      url: generate_url(storage_asset)
    }
  end

  # defp generate_url(%{filename: filename} = repository_asset) when not is_nil(filename),
  #   do: StorageAssetUploader.url({filename, repository_asset}, signed: true)

  # defp generate_url(_), do: nil
  defp generate_url(%{filename: filename} = storage_asset) do
    WraftDocWeb.StorageAssetUploader.url({filename, storage_asset}, signed: true)
  end
  # defp generate_url(%{filename: filename} = storage_asset) when not is_nil(filename),
  #   do: StorageAssetUploader.url({filename, storage_asset}, signed: true)

  defp generate_url(_), do: nil
end
