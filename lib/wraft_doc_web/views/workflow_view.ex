defmodule WraftDocWeb.Api.V1.WorkflowView do
  use WraftDocWeb, :view

  def render("index.json", %{workflows: workflows} = assigns) do
    %{
      workflows: render_many(workflows, __MODULE__, "workflow.json"),
      page_number: Map.get(assigns, :page_number, 1),
      total_pages: Map.get(assigns, :total_pages, 1),
      total_entries: Map.get(assigns, :total_entries, length(workflows))
    }
  end

  def render("show.json", %{workflow: workflow}) do
    render_one(workflow, __MODULE__, "workflow_detail.json")
  end

  def render("workflow.json", %{workflow: workflow}) do
    %{
      id: workflow.id,
      name: workflow.name,
      description: workflow.description,
      is_active: workflow.is_active,
      inserted_at: workflow.inserted_at,
      updated_at: workflow.updated_at
    }
  end

  def render("workflow_detail.json", %{workflow: workflow}) do
    %{
      id: workflow.id,
      name: workflow.name,
      description: workflow.description,
      is_active: workflow.is_active,
      config: workflow.config,
      jobs: render_many(workflow.jobs, __MODULE__, "job.json", as: :job),
      edges: render_many(workflow.edges, __MODULE__, "edge.json", as: :edge),
      inserted_at: workflow.inserted_at,
      updated_at: workflow.updated_at
    }
  end

  def render("job.json", %{job: job}) do
    %{
      id: job.id,
      name: job.name,
      adaptor: job.adaptor,
      config: job.config,
      order: job.order,
      position_x: job.position_x,
      position_y: job.position_y
    }
  end

  def render("edge.json", %{edge: edge}) do
    %{
      id: edge.id,
      source_job_id: edge.source_job_id,
      source_trigger_id: edge.source_trigger_id,
      target_job_id: edge.target_job_id,
      condition_type: edge.condition_type,
      condition_label: edge.condition_label,
      enabled: edge.enabled
    }
  end
end
