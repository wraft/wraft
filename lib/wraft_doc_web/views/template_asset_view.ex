defmodule WraftDocWeb.Api.V1.TemplateAssetView do
  use WraftDocWeb, :view
  alias __MODULE__
  alias WraftDocWeb.Api.V1.UserView

  def render("template_asset.json", %{template_asset: template_asset}) do
    %{
      id: template_asset.id,
      name: template_asset.name,
      file: generate_zip_url(template_asset),
      thumbnail: generate_thumbnail_url(template_asset),
      file_entries: template_asset.file_entries,
      wraft_json: template_asset.wraft_json,
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
        render_many(template_assets, TemplateAssetView, "template_asset.json",
          as: :template_asset
        ),
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

  def render("show_template.json", %{template: template}) do
    %{
      id: template.id,
      title: template.title,
      title_template: template.title_template,
      data: template.data,
      serialized: template.serialized,
      inserted_at: template.inserted_at,
      updated_at: template.updated_at
    }
  end

  def render("list_public_templates.json", %{templates: template_list}) do
    %{
      templates: template_list
    }
  end

  def render("download_public_template.json", %{template_url: template_url}) do
    %{
      template_url: template_url
    }
  end

  defp generate_zip_url(%{zip_file: zip_file} = template_asset) do
    WraftDocWeb.TemplateAssetUploader.url({zip_file, template_asset}, signed: true)
  end

  defp generate_thumbnail_url(%{thumbnail: thumbnail} = template_asset) do
    WraftDocWeb.TemplateAssetThumbnailUploader.url({thumbnail, template_asset}, signed: true)
  end
end
