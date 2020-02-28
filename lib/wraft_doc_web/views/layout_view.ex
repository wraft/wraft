defmodule WraftDocWeb.Api.V1.LayoutView do
  use WraftDocWeb, :view
  alias WraftDocWeb.Api.V1.{EngineView, UserView}
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
      inserted_at: layout.inserted_at,
      update_at: layout.updated_at,
      engine: render_one(layout.engine, EngineView, "create.json", as: :engine)
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
      inserted_at: layout.inserted_at,
      update_at: layout.updated_at
    }
  end

  def render("index.json", %{doc_layouts: layouts}) do
    render_many(layouts, LayoutView, "create.json", as: :doc_layout)
  end

  def render("show.json", %{doc_layout: layout}) do
    %{
      layout: render_one(layout, LayoutView, "create.json", as: :doc_layout),
      creator: render_one(layout.creator, UserView, "user.json", as: :user)
    }
  end
end
