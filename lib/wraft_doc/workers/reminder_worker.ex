defmodule WraftDoc.Workers.ReminderWorker do
  @moduledoc """
  Oban worker for processing document reminders.
  """
  use Oban.Worker, queue: :scheduled, tags: ["reminders"]

  require Logger

  alias WraftDoc.Documents.Reminders

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    Logger.info("Document reminder job started")

    Reminders.process_scheduled_reminders()

    Logger.info("Document reminder job completed")
    :ok
  end
end
