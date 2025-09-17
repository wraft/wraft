defmodule WraftDoc.Workers.WebhookCleanupWorker do
  @moduledoc """
  Oban worker for cleaning up old webhook logs to manage database size.

  This worker runs on a schedule to delete webhook logs older than a configured
  retention period (default: 90 days).
  """
  use Oban.Worker, queue: :scheduled, max_attempts: 3
  require Logger

  alias WraftDoc.Webhooks

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"days_to_keep" => days_to_keep}}) do
    Logger.info("Starting webhook logs cleanup #{days_to_keep}")

    {deleted_count, _} = Webhooks.cleanup_webhook_logs(days_to_keep)

    Logger.info(
      "Webhook logs cleanup completed deleted count #{deleted_count} days to keep #{days_to_keep}"
    )

    :ok
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: _args}) do
    # Default to 90 days retention
    perform(%Oban.Job{args: %{"days_to_keep" => 90}})
  end
end
