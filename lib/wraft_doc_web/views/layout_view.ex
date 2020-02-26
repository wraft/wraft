defmodule WraftDocWeb.Api.V1.LayoutView do
  use WraftDocWeb, :view
  alias WraftDocWeb.Api.V1.EngineView

  def render("create.json", %{doc_layout: layout}) do
    %{
      uuid: layout.uuid,
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
end
