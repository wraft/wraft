defmodule WraftDocWeb.Api.V1.StorageItemView do
  use WraftDocWeb, :view

  alias WraftDocWeb.Api.V1.StorageAssetView

  def render("storage_item.json", %{storage_item: storage_item}) do
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
      asset: render_one(storage_item.storage_asset, StorageAssetView, "storage_asset.json")
    }
  end

  def render("index.json", %{
        data: storage_items,
        meta: meta,
        breadcrumbs: breadcrumbs,
        current_folder: current_folder
      }) do
    %{
      data: render_many(storage_items, __MODULE__, "storage_item.json"),
      meta: meta,
      breadcrumbs: breadcrumbs,
      current_folder: current_folder
    }
  end

  def render("cloud_index.json", %{
        status: status,
        provider: provider,
        storage_items: storage_items
      }) do
    %{
      status: status,
      provider: provider,
      storage_items: render_many(storage_items, __MODULE__, "storage_item.json")
    }
  end

  def render("breadcrumbs.json", %{breadcrumbs: breadcrumbs}) do
    %{data: breadcrumbs}
  end

  def render("navigation.json", %{navigation_data: navigation_data}) do
    %{data: navigation_data}
  end

  def render("show.json", %{storage_item: storage_item}) do
    %{data: render_one(storage_item, __MODULE__, "storage_item.json")}
  end

  def render("delete.json", %{delete: delete}) do
    delete
  end
end
