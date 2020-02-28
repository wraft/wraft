defmodule WraftDocWeb.Api.V1.EngineView do
  use WraftDocWeb, :view
  alias __MODULE__

  def render("create.json", %{engine: engine}) do
    %{
      id: engine.uuid,
      name: engine.name,
      api_route: engine.api_route,
      inserted_at: engine.inserted_at,
      updated_at: engine.updated_at
    }
  end

  def render("index.json", %{engines: engines}) do
    render_many(engines, EngineView, "create.json", as: :engine)
  end
end
