defmodule WraftDocWeb.Api.V1.StorageItemView do
  use WraftDocWeb, :view
  alias WraftDoc.Storage.StorageAsset
  alias WraftDoc.Storage.StorageItem

  def render("index.json", %{storage_items: storage_items}) do
    storage_items
  end

  def render("breadcrumbs.json", %{breadcrumbs: breadcrumbs}) do
    %{data: breadcrumbs}
  end

  def render("navigation.json", %{navigation_data: navigation_data}) do
    %{data: navigation_data}
  end

  def render("show.json", %{storage_item: storage_item, storage_assets: storage_assets}) do
    %{data: data(storage_item, storage_assets)}
  end

  def render("storage_item.json", %{storage_item: storage_item, storage_assets: storage_assets}) do
    %{data: data(storage_item, storage_assets)}
  end

  def render("delete.json", %{delete: delete}) do
    delete
  end

  @doc """
  Renders a single storage item.
  """
  def show(%{storage_item: storage_item}) do
    %{data: data(storage_item)}
  end

  @doc """
  Formats storage item data for response
  """
  def data(%StorageItem{} = storage_item, storage_assets \\ []) do
    %{
      id: storage_item.id,
      name: storage_item.name,
      display_name: storage_item.display_name,
      item_type: storage_item.item_type,
      path: storage_item.path,
      mime_type: storage_item.mime_type,
      file_extension: storage_item.file_extension,
      size: storage_item.size,
      is_folder: storage_item.mime_type == "inode/directory",
      depth_level: storage_item.depth_level,
      materialized_path: storage_item.materialized_path,
      version_number: storage_item.version_number,
      is_current_version: storage_item.is_current_version,
      classification_level: storage_item.classification_level,
      content_extracted: storage_item.content_extracted,
      thumbnail_generated: storage_item.thumbnail_generated,
      download_count: storage_item.download_count,
      last_accessed_at: storage_item.last_accessed_at,
      metadata: storage_item.metadata,
      parent_id: storage_item.parent_id,
      repository_id: storage_item.repository_id,
      upload_status: storage_item.upload_status,
      creator_id: storage_item.creator_id,
      organisation_id: storage_item.organisation_id,
      inserted_at: storage_item.inserted_at,
      updated_at: storage_item.updated_at,
      assets: Enum.map(storage_assets, &storage_asset_data/1)
    }
  end

  @doc """
  Formats storage asset data for response
  """
  def storage_asset_data(%StorageAsset{} = storage_asset) do
    %{
      id: storage_asset.id,
      filename: storage_asset.filename,
      storage_key: storage_asset.storage_key,
      storage_backend: storage_asset.storage_backend,
      file_size: storage_asset.file_size,
      mime_type: storage_asset.mime_type,
      processing_status: storage_asset.processing_status,
      upload_completed_at: storage_asset.upload_completed_at,
      checksum_sha256: storage_asset.checksum_sha256,
      thumbnail_path: storage_asset.thumbnail_path,
      preview_path: storage_asset.preview_path,
      inserted_at: storage_asset.inserted_at,
      updated_at: storage_asset.updated_at,
      url: generate_url(storage_asset)
    }
  end

  defp generate_url(storage_asset) do
    WraftDocWeb.StorageAssetUploader.url({storage_asset.filename, storage_asset}, signed: true)
  end
end
