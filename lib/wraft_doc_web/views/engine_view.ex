defmodule WraftDocWeb.Api.V1.EngineView do
  use WraftDocWeb, :view
  alias __MODULE__

  def render("create.json", %{engine: engine}) do
    %{
      id: engine.id,
      name: engine.name,
      api_route: engine.api_route,
      inserted_at: engine.inserted_at,
      updated_at: engine.updated_at
    }
  end

  def render("index.json", %{
        engines: engines,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      }) do
    %{
      engines: render_many(engines, EngineView, "create.json", as: :engine),
      page_number: page_number,
      total_pages: total_pages,
      total_entries: total_entries
    }
  end
end
