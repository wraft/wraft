defmodule WraftDocWeb.Api.V1.StorageAssetView do
  use WraftDocWeb, :view

  alias WraftDoc.Storages.StorageAsset
  alias WraftDocWeb.Api.V1.StorageItemView

  def render("storage_asset.json", %{storage_asset: storage_asset}) do
    %{
      id: storage_asset.id,
      file_name: storage_asset.filename,
      file_size: storage_asset.file_size,
      mime_type: storage_asset.mime_type,
      url: generate_url(storage_asset),
      preview_url: generate_preview_url(storage_asset),
      inserted_at: storage_asset.inserted_at,
      updated_at: storage_asset.updated_at
    }
  end

  def render("index.json", %{storage_assets: storage_assets}) do
    %{
      data: render_many(storage_assets, __MODULE__, "storage_asset.json"),
      meta: %{
        count: length(storage_assets)
      }
    }
  end

  def render("show.json", %{storage_asset: storage_asset}) do
    %{data: render_one(storage_asset, __MODULE__, "storage_asset.json")}
  end

  def render("show_upload.json", %{storage_item: storage_item}) do
    %{
      data: %{
        storage_item: render_one(storage_item, StorageItemView, "storage_item.json")
      }
    }
  end

  defp generate_url(%StorageAsset{filename: filename} = storage_asset),
    do: WraftDocWeb.StorageAssetUploader.url({filename, storage_asset}, :original, signed: true)

  defp generate_preview_url(%StorageAsset{filename: filename} = storage_asset),
    do: WraftDocWeb.StorageAssetUploader.url({filename, storage_asset}, :preview, signed: true)
end
