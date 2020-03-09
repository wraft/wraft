defmodule WraftDocWeb.Api.V1.AssetView do
  use WraftDocWeb, :view

  def render("asset.json", %{asset: asset}) do
    %{
      id: asset.uuid,
      name: asset.name,
      inserted_at: asset.inserted_at,
      updated_at: asset.updated_at
    }
  end
end
