defmodule WraftDocWeb.Api.V1.LayoutView do
  use WraftDocWeb, :view
  alias WraftDocWeb.Api.V1.{AssetView, EngineView, UserView}
  alias __MODULE__

  def render("create.json", %{doc_layout: layout}) do
    %{
      id: layout.uuid,
      name: layout.name,
      description: layout.description,
      width: layout.width,
      height: layout.height,
      unit: layout.unit,
      slug: layout.slug,
      slug_file: generate_url(layout),
      screenshot: generate_ss_url(layout),
      inserted_at: layout.inserted_at,
      update_at: layout.updated_at,
      engine: render_one(layout.engine, EngineView, "create.json", as: :engine),
      assets: render_many(layout.assets, AssetView, "asset.json", as: :asset)
    }
  end

  def render("layout.json", %{doc_layout: layout}) do
    %{
      id: layout.uuid,
      name: layout.name,
      description: layout.description,
      width: layout.width,
      height: layout.height,
      unit: layout.unit,
      slug: layout.slug,
      slug_file: generate_url(layout),
      screenshot: generate_ss_url(layout),
      inserted_at: layout.inserted_at,
      update_at: layout.updated_at
    }
  end

  def render("index.json", %{
        doc_layouts: layouts,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      }) do
    %{
      layouts: render_many(layouts, LayoutView, "create.json", as: :doc_layout),
      page_number: page_number,
      total_pages: total_pages,
      total_entries: total_entries
    }
  end

  def render("show.json", %{doc_layout: layout}) do
    %{
      layout: render_one(layout, LayoutView, "create.json", as: :doc_layout),
      creator: render_one(layout.creator, UserView, "user.json", as: :user)
    }
  end

  defp generate_url(%{slug_file: file} = layout) do
    WraftDocWeb.LayoutSlugUploader.url({file, layout})
  end

  defp generate_ss_url(%{screenshot: file} = layout) do
    WraftDocWeb.LayoutScreenShotUploader.url({file, layout})
  end
end
