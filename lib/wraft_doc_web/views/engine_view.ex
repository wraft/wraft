defmodule WraftDocWeb.Api.V1.EngineView do
  use WraftDocWeb, :view

  def render("create.json", %{engine: engine}) do
    %{
      id: engine.uuid,
      name: engine.name,
      api_route: engine.api_route,
      inserted_at: engine.inserted_at,
      updated_at: engine.updated_at
    }
  end
end
