defmodule WraftDocWeb.Api.V1.PipelineView do
  use WraftDocWeb, :view
  alias __MODULE__
  alias WraftDocWeb.Api.V1.ContentTypeView

  def render("create.json", %{pipeline: pipeline}) do
    %{
      id: pipeline.uuid,
      name: pipeline.name,
      api_route: pipeline.api_route,
      inserted_at: pipeline.inserted_at,
      updated_at: pipeline.updated_at,
      content_types:
        render_many(pipeline.content_types, ContentTypeView, "content_type.json",
          as: :content_type
        )
    }
  end

  def render("index.json", %{
        pipelines: pipelines,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      }) do
    %{
      pipelines: render_many(pipelines, PipelineView, "pipeline.json", as: :pipeline),
      page_number: page_number,
      total_pages: total_pages,
      total_entries: total_entries
    }
  end

  def render("pipeline.json", %{pipeline: pipeline}) do
    %{
      id: pipeline.uuid,
      name: pipeline.name,
      api_route: pipeline.api_route,
      inserted_at: pipeline.inserted_at,
      updated_at: pipeline.updated_at
    }
  end
end
