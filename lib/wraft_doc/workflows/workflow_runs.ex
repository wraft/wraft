defmodule WraftDoc.Workflows.WorkflowRuns do
  @moduledoc """
  Context for managing workflow runs and execution.
  """

  import Ecto.Query

  alias WraftDoc.Account.User
  alias WraftDoc.Repo
  alias WraftDoc.Workers.WorkflowExecutionWorker
  alias WraftDoc.Workflows.Workflow
  alias WraftDoc.Workflows.WorkflowRun
  alias WraftDoc.Workflows.WorkflowTrigger

  @doc """
  Create a new workflow run and enqueue it for async execution.
  """
  def create_and_execute_run(%User{current_org_id: org_id}, workflow_id, input_data) do
    with {:ok, workflow} <- get_workflow_for_org(workflow_id, org_id),
         {:ok, run} <- create_run(workflow, input_data),
         {:ok, _job} <- WorkflowExecutionWorker.enqueue_run(run.id) do
      {:ok, run}
    end
  end

  @doc """
  Get a workflow run with all job executions.
  """
  def get_run(%User{current_org_id: org_id}, run_id) do
    query =
      WorkflowRun
      |> where([r], r.id == ^run_id)
      |> join(:inner, [r], w in assoc(r, :workflow))

    # Handle nil org_id - Ecto doesn't allow direct comparison with nil
    query =
      if is_nil(org_id) do
        where(query, [r, w], is_nil(w.organisation_id))
      else
        where(query, [r, w], w.organisation_id == ^org_id)
      end

    query
    |> preload(run_jobs: [job: :workflow], workflow: [:jobs, :edges])
    |> Repo.one()
  end

  @doc """
  List workflow runs for a workflow.
  """
  def list_runs(%User{current_org_id: org_id}, workflow_id, params \\ %{}) do
    query =
      WorkflowRun
      |> join(:inner, [r], w in assoc(r, :workflow))
      |> where([r, w], r.workflow_id == ^workflow_id)

    # Handle nil org_id - Ecto doesn't allow direct comparison with nil
    query =
      if is_nil(org_id) do
        where(query, [r, w], is_nil(w.organisation_id))
      else
        where(query, [r, w], w.organisation_id == ^org_id)
      end

    query
    |> order_by([r], desc: r.inserted_at)
    |> preload(run_jobs: :job)
    |> Repo.paginate(params)
  end

  @doc """
  Get the latest run for a workflow.
  """
  def get_latest_run(%User{current_org_id: org_id}, workflow_id) do
    query =
      WorkflowRun
      |> join(:inner, [r], w in assoc(r, :workflow))
      |> where([r, w], r.workflow_id == ^workflow_id)

    # Handle nil org_id - Ecto doesn't allow direct comparison with nil
    query =
      if is_nil(org_id) do
        where(query, [r, w], is_nil(w.organisation_id))
      else
        where(query, [r, w], w.organisation_id == ^org_id)
      end

    query
    |> order_by([r], desc: r.inserted_at)
    |> limit(1)
    |> preload(run_jobs: :job)
    |> Repo.one()
  end

  defp get_workflow_for_org(workflow_id, org_id) do
    query = where(Workflow, [w], w.id == ^workflow_id)

    # Handle nil org_id - Ecto doesn't allow direct comparison with nil
    query =
      if is_nil(org_id) do
        where(query, [w], is_nil(w.organisation_id))
      else
        where(query, [w], w.organisation_id == ^org_id)
      end

    workflow = Repo.one(query)

    if workflow, do: {:ok, workflow}, else: {:error, :workflow_not_found}
  end

  defp create_run(workflow, input_data) do
    %WorkflowRun{}
    |> WorkflowRun.changeset(%{
      workflow_id: workflow.id,
      state: "pending",
      input_data: input_data
    })
    |> Repo.insert()
  end

  @doc """
  Create a workflow run for webhook trigger and execute it.
  """
  @spec create_and_execute_run_for_webhook(WorkflowTrigger.t(), map()) ::
          {:ok, WorkflowRun.t()} | {:error, term()}
  def create_and_execute_run_for_webhook(
        %WorkflowTrigger{workflow_id: workflow_id} = trigger,
        input_data
      ) do
    with {:ok, workflow} <- get_workflow(workflow_id),
         {:ok, run} <- create_run_for_trigger(workflow, trigger, input_data),
         {:ok, _job} <- WorkflowExecutionWorker.enqueue_run(run.id) do
      {:ok, run}
    end
  end

  defp get_workflow(workflow_id) do
    workflow =
      Workflow
      |> where([w], w.id == ^workflow_id and w.is_active == true)
      |> Repo.one()

    if workflow, do: {:ok, workflow}, else: {:error, :workflow_not_found}
  end

  defp create_run_for_trigger(workflow, trigger, input_data) do
    %WorkflowRun{}
    |> WorkflowRun.changeset(%{
      workflow_id: workflow.id,
      trigger_id: trigger.id,
      state: "pending",
      input_data: input_data
    })
    |> Repo.insert()
  end
end
