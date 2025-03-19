defmodule WraftDoc.Workers.ContractReminderWorker do
  @moduledoc """
  Oban worker for processing contract reminders.
  """
  use Oban.Worker, queue: :scheduled, tags: ["contract_reminders"]

  require Logger

  alias WraftDoc.Documents.ContractReminders

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    Logger.info("Contract reminder job started")

    ContractReminders.process_scheduled_reminders()

    Logger.info("Contract reminder job completed")
    :ok
  end

  @doc """
  Schedule the contract reminder job to run daily
  """
  def schedule_daily_job do
    %{}
    |> new(schedule_in: {1, :day})
    |> Oban.insert()
  end
end
