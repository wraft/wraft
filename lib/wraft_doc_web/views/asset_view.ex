defmodule WraftDocWeb.Api.V1.AssetView do
  use WraftDocWeb, :view
  alias __MODULE__

  def render("asset.json", %{asset: asset}) do
    %{
      id: asset.uuid,
      name: asset.name,
      inserted_at: asset.inserted_at,
      updated_at: asset.updated_at
    }
  end

  def render("index.json", %{assets: assets}) do
    render_many(assets, AssetView, "asset.json", as: :asset)
  end
end
