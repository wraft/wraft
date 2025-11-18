defmodule WraftDoc.Workers.WorkflowScheduledTriggerWorker do
  @moduledoc """
  Oban worker for scheduled workflow triggers (cron-based).

  Executes workflows on schedule using cron expressions.
  """

  use Oban.Worker, queue: :scheduled, max_attempts: 1

  require Logger

  alias WraftDoc.Repo
  alias WraftDoc.Workflows.WorkflowRuns
  alias WraftDoc.Workflows.WorkflowTrigger

  import Ecto.Query

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"trigger_id" => trigger_id}}) do
    Logger.info("[WorkflowScheduledTriggerWorker] Processing scheduled trigger #{trigger_id}")

    case Repo.get(WorkflowTrigger, trigger_id) do
      nil ->
        Logger.warning("[WorkflowScheduledTriggerWorker] Trigger #{trigger_id} not found")
        :ok

      trigger ->
        if trigger.is_active && trigger.type == "scheduled" do
          execute_scheduled_trigger(trigger)
        else
          Logger.info(
            "[WorkflowScheduledTriggerWorker] Trigger #{trigger_id} is inactive or not scheduled"
          )

          :ok
        end
    end
  end

  defp execute_scheduled_trigger(%WorkflowTrigger{workflow_id: workflow_id, config: config}) do
    # Get input data from config or use empty map
    input_data = Map.get(config, "input_data", %{})

    Logger.info("[WorkflowScheduledTriggerWorker] Executing workflow #{workflow_id} on schedule")

    # Create and execute workflow run
    case WorkflowRuns.create_and_execute_run_for_webhook(
           %WorkflowTrigger{workflow_id: workflow_id},
           input_data
         ) do
      {:ok, _run} ->
        Logger.info(
          "[WorkflowScheduledTriggerWorker] Successfully executed workflow #{workflow_id}"
        )

        :ok

      {:error, reason} ->
        Logger.error(
          "[WorkflowScheduledTriggerWorker] Failed to execute workflow #{workflow_id}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  @doc """
  Find all active scheduled triggers and enqueue them for execution.
  This should be called by Oban.Cron plugin.
  """
  def enqueue_scheduled_triggers do
    active_triggers =
      WorkflowTrigger
      |> where([t], t.type == "scheduled" and t.is_active == true)
      |> Repo.all()

    Logger.info(
      "[WorkflowScheduledTriggerWorker] Found #{length(active_triggers)} active scheduled triggers"
    )

    Enum.each(active_triggers, fn trigger ->
      # This will be called by cron, but we can also manually enqueue
      # For now, we'll rely on cron to call perform directly
      Logger.debug("[WorkflowScheduledTriggerWorker] Processing trigger #{trigger.id}")
    end)

    :ok
  end
end
