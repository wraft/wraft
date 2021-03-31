defmodule WraftDocWeb.Api.V1.AssetView do
  use WraftDocWeb, :view
  alias __MODULE__
  alias WraftDocWeb.Api.V1.UserView

  def render("asset.json", %{asset: asset}) do
    %{
      id: asset.uuid,
      name: asset.name,
      file: generate_url(asset),
      inserted_at: asset.inserted_at,
      updated_at: asset.updated_at
    }
  end

  def render("index.json", %{
        assets: assets,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      }) do
    %{
      assets: render_many(assets, AssetView, "asset.json", as: :asset),
      page_number: page_number,
      total_pages: total_pages,
      total_entries: total_entries
    }
  end

  def render("show.json", %{asset: asset}) do
    %{
      asset: render_one(asset, AssetView, "asset.json", as: :asset),
      creator: render_one(asset.creator, UserView, "user.json", as: :user)
    }
  end

  defp generate_url(%{file: file} = asset) do
    WraftDocWeb.AssetUploader.url({file, asset})
  end
end
