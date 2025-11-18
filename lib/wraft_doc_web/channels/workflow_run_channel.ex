defmodule WraftDocWeb.Channels.WorkflowRunChannel do
  @moduledoc """
  Phoenix channel for workflow runs.
  """
  use Phoenix.Channel
  alias WraftDoc.Repo
  alias WraftDoc.Workflows.WorkflowRuns

  require Logger

  @impl true
  def join("workflow_run:" <> run_id, _payload, socket) do
    current_user = socket.assigns.current_user

    case WorkflowRuns.get_run(current_user, run_id) do
      nil ->
        Logger.warning("[WorkflowRunChannel] Run not found: #{run_id}")
        {:error, %{reason: "not_found"}}

      run ->
        run = Repo.preload(run, run_jobs: :job, workflow: [:jobs, :edges])
        {:ok, %{run: serialize_run(run)}, assign(socket, :run_id, run_id)}
    end
  end

  @impl true
  def handle_in("fetch_run", _payload, socket) do
    run_id = socket.assigns.run_id
    current_user = socket.assigns.current_user

    case WorkflowRuns.get_run(current_user, run_id) do
      nil ->
        {:reply, {:error, %{reason: "not_found"}}, socket}

      run ->
        run = Repo.preload(run, run_jobs: :job, workflow: [:jobs, :edges])
        {:reply, {:ok, %{run: serialize_run(run)}}, socket}
    end
  end

  # Handle broadcasts from DAG engine
  @impl true
  def handle_info(%{event: "run_job_started", run_job: run_job}, socket) do
    run_job = Repo.preload(run_job, :job)
    push(socket, "run_job:started", %{run_job: serialize_run_job(run_job)})
    {:noreply, socket}
  end

  def handle_info(%{event: "run_job_completed", run_job: run_job}, socket) do
    run_job = Repo.preload(run_job, :job)
    push(socket, "run_job:completed", %{run_job: serialize_run_job(run_job)})
    {:noreply, socket}
  end

  def handle_info(%{event: "run_job_failed", run_job: run_job}, socket) do
    run_job = Repo.preload(run_job, :job)
    push(socket, "run_job:failed", %{run_job: serialize_run_job(run_job)})
    {:noreply, socket}
  end

  def handle_info(%{event: "run_completed", run: run}, socket) do
    run = Repo.preload(run, run_jobs: :job, workflow: [:jobs, :edges])
    push(socket, "run:completed", %{run: serialize_run(run)})
    {:noreply, socket}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  defp serialize_run(run) do
    %{
      id: run.id,
      workflow_id: run.workflow_id,
      state: run.state,
      input_data: run.input_data,
      started_at: run.started_at,
      completed_at: run.completed_at,
      duration_ms: run.duration_ms,
      run_jobs: Enum.map(run.run_jobs || [], &serialize_run_job/1)
    }
  end

  defp serialize_run_job(run_job) do
    %{
      id: run_job.id,
      run_id: run_job.run_id,
      job_id: run_job.job_id,
      job: %{
        id: run_job.job.id,
        name: run_job.job.name,
        adaptor: run_job.job.adaptor
      },
      state: run_job.state,
      input_data: run_job.input_data,
      output_data: run_job.output_data,
      error: run_job.error,
      started_at: run_job.started_at,
      completed_at: run_job.completed_at,
      duration_ms: run_job.duration_ms
    }
  end
end
