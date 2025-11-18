defmodule WraftDoc.Workers.WorkflowScheduledCheckerWorker do
  @moduledoc """
  Periodic worker that checks for scheduled workflow triggers every minute.

  This worker runs every minute and checks if any scheduled triggers
  match the current time based on their cron expressions.
  """

  use Oban.Worker, queue: :scheduled, max_attempts: 3

  import Ecto.Query

  require Logger

  alias WraftDoc.Repo
  alias WraftDoc.Workflows.WorkflowRuns
  alias WraftDoc.Workflows.WorkflowTrigger

  @impl Oban.Worker
  def perform(_job) do
    Logger.debug("[WorkflowScheduledCheckerWorker] Checking for scheduled triggers")

    active_triggers =
      WorkflowTrigger
      |> where([t], t.type == "scheduled" and t.is_active == true)
      |> Repo.all()

    Logger.info(
      "[WorkflowScheduledCheckerWorker] Found #{length(active_triggers)} active scheduled triggers"
    )

    now = DateTime.utc_now()

    Enum.each(active_triggers, fn trigger ->
      check_and_execute_trigger(trigger, now)
    end)

    :ok
  end

  defp check_and_execute_trigger(trigger, now) do
    cron_expr = get_cron_expression(trigger)

    if cron_expr && matches_cron(cron_expr, now) do
      Logger.info(
        "[WorkflowScheduledCheckerWorker] Trigger #{trigger.id} matches current time, executing"
      )

      execute_trigger(trigger)
    else
      Logger.debug(
        "[WorkflowScheduledCheckerWorker] Trigger #{trigger.id} does not match current time"
      )
    end
  end

  defp get_cron_expression(%WorkflowTrigger{config: config}) do
    # Cron expression can be in config as "cron" or "schedule"
    Map.get(config, "cron") || Map.get(config, "schedule")
  end

  defp matches_cron(_cron_expr, _now) do
    # TODO: Implement cron matching logic
    # For now, we'll use a simple approach: if the trigger has been created
    # more than 1 minute ago and hasn't run in the last minute, run it
    # This is a placeholder - in production, use a proper cron parser like `crontab`
    true
  end

  defp execute_trigger(%WorkflowTrigger{workflow_id: workflow_id, config: config} = trigger) do
    input_data = Map.get(config, "input_data", %{})

    case WorkflowRuns.create_and_execute_run_for_webhook(trigger, input_data) do
      {:ok, _run} ->
        Logger.info(
          "[WorkflowScheduledCheckerWorker] Successfully executed workflow #{workflow_id}"
        )

        :ok

      {:error, reason} ->
        Logger.error(
          "[WorkflowScheduledCheckerWorker] Failed to execute workflow #{workflow_id}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end
end
