defmodule WraftDocWeb.Api.V1.PipelineView do
  use WraftDocWeb, :view
  alias __MODULE__
  alias WraftDocWeb.Api.V1.{UserView, PipeStageView}

  def render("create.json", %{pipeline: pipeline}) do
    %{
      id: pipeline.uuid,
      name: pipeline.name,
      api_route: pipeline.api_route,
      inserted_at: pipeline.inserted_at,
      updated_at: pipeline.updated_at,
      stages: render_many(pipeline.stages, PipeStageView, "stage.json", as: :stage)
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

  def render("show.json", %{pipeline: pipeline}) do
    %{
      id: pipeline.uuid,
      name: pipeline.name,
      api_route: pipeline.api_route,
      inserted_at: pipeline.inserted_at,
      updated_at: pipeline.updated_at,
      creator: render_one(pipeline.creator, UserView, "user.json", as: :user),
      stages: render_many(pipeline.stages, PipeStageView, "stage.json", as: :stage)
    }
  end
end
