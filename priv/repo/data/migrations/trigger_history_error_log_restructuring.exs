defmodule WraftDoc.Repo.Migrations.TriggerHistoryErrorLogRestructuring do
  @moduledoc """
  Script for restructuring trigger_history error log
   mix run priv/repo/data/migrations/trigger_history_error_log_restructuring.exs
  """

  require Logger
  alias WraftDoc.Document.Pipeline.TriggerHistory
  alias WraftDoc.Repo

  Logger.info("Restructuring trigger_history error log")

  TriggerHistory
  |> Repo.all()
  |> Enum.group_by(& &1.state)
  |> Enum.each(fn {state, trigger_histories} ->
    Logger.info(
      "Trigger history state #{state} has #{length(trigger_histories)} trigger histories"
    )

    case state do
      3 ->
        Enum.each(trigger_histories, fn trigger_history ->
          [failure_time] = Map.keys(trigger_history.error)

          trigger_history
          |> TriggerHistory.update_changeset(%{
            error: %{
              "failure_time" => failure_time,
              info: "Values Provided Incorrectly",
              message:
                "The provided data values are incomplete or missing for the required fields in the document template. Please check your data mapping and ensure all necessary values are provided.",
              stage: trigger_history.error[failure_time]["stage"]
            }
          })
          |> Repo.update!()
        end)

      4 ->
        Enum.each(trigger_histories, fn trigger_history ->
          [failure_time] = Map.keys(trigger_history.error)

          trigger_history
          |> TriggerHistory.update_changeset(%{
            error: %{
              "failure_time" => failure_time,
              info: "Builds Failed",
              message: "Some builds failed. Please check the logs for more information.",
              zipfile: trigger_history.error[failure_time]["zipfile"],
              failed_builds: trigger_history.error[failure_time]["failed_builds"]
            }
          })
          |> Repo.update!()
        end)

      _ ->
        nil
    end
  end)

  Logger.info("Finished restructuring trigger_history error log")
end
