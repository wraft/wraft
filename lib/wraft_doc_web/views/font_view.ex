defmodule WraftDocWeb.Api.V1.FontView do
  use WraftDocWeb, :view

  alias WraftDocWeb.Api.V1.AssetView

  def render("index.json", %{fonts: fonts}) do
    %{data: render_many(fonts, __MODULE__, "font.json")}
  end

  def render("show.json", %{font: font}) do
    %{data: render_one(font, __MODULE__, "font.json")}
  end

  def render("font.json", %{font: font}) do
    %{
      id: font.id,
      name: font.name,
      assets: render_many(font.assets, AssetView, "asset.json", as: :asset),
      organisation_id: font.organisation_id,
      creator_id: font.creator_id
    }
  end
end
