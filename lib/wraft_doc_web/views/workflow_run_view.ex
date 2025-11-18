defmodule WraftDocWeb.Api.V1.WorkflowRunView do
  use WraftDocWeb, :view

  alias WraftDocWeb.Api.V1.WorkflowView

  def render("index.json", %{runs: runs} = assigns) do
    %{
      runs: render_many(runs, __MODULE__, "run.json"),
      page_number: Map.get(assigns, :page_number, 1),
      total_pages: Map.get(assigns, :total_pages, 1),
      total_entries: Map.get(assigns, :total_entries, length(runs))
    }
  end

  def render("show.json", %{run: run}) do
    render_one(run, __MODULE__, "run_detail.json")
  end

  def render("run.json", %{workflow_run: run}) do
    %{
      id: run.id,
      workflow_id: run.workflow_id,
      state: run.state,
      started_at: run.started_at,
      completed_at: run.completed_at,
      duration_ms: run.duration_ms,
      inserted_at: run.inserted_at
    }
  end

  def render("run_detail.json", %{workflow_run: run}) do
    %{
      id: run.id,
      workflow_id: run.workflow_id,
      state: run.state,
      input_data: run.input_data,
      output_data: run.output_data,
      error: run.error,
      started_at: run.started_at,
      completed_at: run.completed_at,
      duration_ms: run.duration_ms,
      workflow: render_workflow(run),
      run_jobs: render_many(run.run_jobs, __MODULE__, "run_job.json", as: :run_job),
      inserted_at: run.inserted_at,
      updated_at: run.updated_at
    }
  end

  def render("run_job.json", %{run_job: run_job}) do
    %{
      id: run_job.id,
      job_id: run_job.job_id,
      job_name: run_job.job.name,
      state: run_job.state,
      input_data: run_job.input_data,
      output_data: run_job.output_data,
      error: run_job.error,
      started_at: run_job.started_at,
      completed_at: run_job.completed_at,
      duration_ms: run_job.duration_ms,
      retry_count: run_job.retry_count
    }
  end

  defp render_workflow(%{workflow: %Ecto.Association.NotLoaded{}}), do: nil
  defp render_workflow(%{workflow: nil}), do: nil

  defp render_workflow(%{workflow: workflow}) do
    %{
      id: workflow.id,
      name: workflow.name,
      jobs: render_many(workflow.jobs, WorkflowView, "job.json", as: :job),
      edges: render_many(workflow.edges, WorkflowView, "edge.json", as: :edge)
    }
  end
end
