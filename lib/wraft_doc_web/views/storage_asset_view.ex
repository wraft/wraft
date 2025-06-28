defmodule WraftDocWeb.Api.V1.StorageAssetView do
  use WraftDocWeb, :view
  alias WraftDoc.Storage.StorageAsset
  alias WraftDoc.Storage.StorageItem

  def render("index.json", %{storage_assets: storage_assets}) do
    %{
      data: Enum.map(storage_assets, &storage_asset_json/1),
      meta: %{
        count: length(storage_assets)
      }
    }
  end

  def render("show.json", %{storage_asset: storage_asset}) do
    %{data: storage_asset_json(storage_asset)}
  end

  def render("show_upload.json", %{storage_asset: storage_asset, storage_item: storage_item}) do
    %{
      data: %{
        storage_asset: storage_asset_json(storage_asset),
        storage_item: storage_item_json(storage_item)
      }
    }
  end

  defp storage_asset_json(%StorageAsset{} = asset) do
    %{
      id: asset.id,
      file_name: asset.filename,
      file_size: asset.file_size,
      mime_type: asset.mime_type,
      storage_key: asset.storage_key,
      inserted_at: asset.inserted_at,
      updated_at: asset.updated_at
    }
  end

  defp storage_item_json(%StorageItem{} = item) do
    %{
      id: item.id,
      display_name: item.display_name,
      parent_id: item.parent_id,
      repository_id: item.repository_id,
      inserted_at: item.inserted_at,
      updated_at: item.updated_at
    }
  end
end
