defmodule WraftDoc.Workers.WorkflowExecutionWorker do
  @moduledoc """
  Oban worker for async workflow execution.

  Enqueues workflow runs for background processing using the DAG engine.
  """

  use Oban.Worker, queue: :workflows, max_attempts: 3

  require Logger

  alias WraftDoc.Workflows.DagEngine

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"run_id" => run_id}}) do
    Logger.info("[WorkflowExecutionWorker] Starting execution for run #{run_id}")

    case DagEngine.execute_run(run_id) do
      {:ok, _run} ->
        Logger.info("[WorkflowExecutionWorker] Successfully completed run #{run_id}")
        :ok

      {:error, reason} = error ->
        Logger.error(
          "[WorkflowExecutionWorker] Execution failed for run #{run_id}: #{inspect(reason)}"
        )

        error
    end
  end

  @doc """
  Enqueue a workflow run for execution.

  ## Examples

      iex> WorkflowExecutionWorker.enqueue_run(run_id)
      {:ok, %Oban.Job{}}

      iex> WorkflowExecutionWorker.enqueue_run(run_id, schedule_in: 60)
      {:ok, %Oban.Job{}}
  """
  @spec enqueue_run(Ecto.UUID.t(), keyword()) :: {:ok, Oban.Job.t()} | {:error, term()}
  def enqueue_run(run_id, opts \\ []) do
    %{"run_id" => run_id}
    |> new(opts)
    |> Oban.insert()
  end
end
