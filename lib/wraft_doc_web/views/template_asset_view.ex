defmodule WraftDocWeb.Api.V1.TemplateAssetView do
  use WraftDocWeb, :view

  alias __MODULE__
  alias WraftDocWeb.Api.V1.AssetView
  alias WraftDocWeb.Api.V1.UserView
  alias WraftDocWeb.TemplateAssetThumbnailUploader

  def render("template_asset.json", %{template_asset: template_asset}) do
    %{
      id: template_asset.id,
      name: template_asset.name,
      description: template_asset.description,
      file_size: template_asset.zip_file_size,
      thumbnail: generate_thumbnail_url(template_asset),
      asset: render_one(template_asset.asset, AssetView, "asset.json", as: :asset),
      file_entries: template_asset.file_entries,
      meta: template_asset.wraft_json,
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

  def render("show_template.json", %{result: result}) do
    %{
      message: "Template imported successfully",
      items:
        Enum.map(result, fn {key, value} ->
          field_name = if Map.has_key?(value, :title), do: :title, else: :name

          %{
            "item_type" => to_string(key),
            "id" => value.id,
            field_name => Map.get(value, field_name),
            "created_at" => value.inserted_at
          }
        end)
    }
  end

  def render("template_pre_import.json", %{result: result}) do
    %{
      existing_items: result.existing_items,
      missing_items: result.missing_items
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

  defp generate_thumbnail_url(%{thumbnail: thumbnail} = template_asset) do
    TemplateAssetThumbnailUploader.url({thumbnail, template_asset}, signed: true)
  end
end
