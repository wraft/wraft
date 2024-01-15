defmodule WraftDocWeb.Api.V1.TemplateAssetView do
  use WraftDocWeb, :view
  alias __MODULE__
  alias WraftDocWeb.Api.V1.UserView

  def render("template_asset.json", %{template_asset: template_asset}) do
    %{
      id: template_asset.id,
      name: template_asset.name,
      file: generate_url(template_asset),
      inserted_at: template_asset.inserted_at,
      updated_at: template_asset.updated_at
    }
  end

  def render("index.json", %{
        template_assets: template_assets,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      }) do
    %{
      template_assets:
        render_many(template_assets, TemplateAssetView, "template_asset.json", as: :template_asset),
      page_number: page_number,
      total_pages: total_pages,
      total_entries: total_entries
    }
  end

  def render("show.json", %{template_asset: template_asset}) do
    %{
      template_asset:
        render_one(template_asset, TemplateAssetView, "template_asset.json", as: :template_asset),
      creator: render_one(template_asset.creator, UserView, "user.json", as: :user)
    }
  end

  defp generate_url(%{file: file} = template_asset) do
    WraftDocWeb.TemplateAssetUploader.url({file, template_asset}, signed: true)
  end
end
