defmodule WraftDocWeb.Api.V1.LayoutView do
  use WraftDocWeb, :view
  alias WraftDoc.Layouts.Layout
  alias WraftDocWeb.Api.V1.AssetView
  alias WraftDocWeb.Api.V1.EngineView
  alias WraftDocWeb.Api.V1.FrameView
  alias WraftDocWeb.Api.V1.UserView
  alias __MODULE__

  def render("create.json", %{doc_layout: layout}) do
    %{
      id: layout.id,
      name: layout.name,
      description: layout.description,
      width: layout.width,
      height: layout.height,
      unit: layout.unit,
      slug: layout.slug,
      frame: render_frame(layout),
      margin: layout.margin,
      screenshot: generate_ss_url(layout),
      inserted_at: layout.inserted_at,
      update_at: layout.updated_at,
      engine: render_one(layout.engine, EngineView, "create.json", as: :engine),
      asset: render_one(layout.asset, AssetView, "asset.json", as: :asset)
    }
  end

  def render("layout.json", %{doc_layout: layout}) do
    %{
      id: layout.id,
      name: layout.name,
      description: layout.description,
      width: layout.width,
      height: layout.height,
      unit: layout.unit,
      slug: layout.slug,
      frame: render_frame(layout),
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

  defp generate_ss_url(%{screenshot: file} = layout) do
    WraftDocWeb.LayoutScreenShotUploader.url({file, layout}, signed: true)
  end

  # HACK: Handle nil case of frame, frame is optional.
  defp render_frame(%Layout{frame: %WraftDoc.Frames.Frame{} = frame}),
    do: render_one(frame, FrameView, "create.json", as: :frame)

  defp render_frame(_), do: nil
end
