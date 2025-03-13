defmodule WraftDoc.Workers.DocumentWorker do
  @moduledoc """
  Oban worker for building of docs.
  """
  use Oban.Worker, queue: :events, max_attempts: 1

  alias WraftDoc.Documents
  require Logger

  @impl Oban.Worker
  def perform(%Job{
        args: %{
          "user" => user,
          "build_history" => build_history,
          "instance" => instance,
          "layout" => layout,
          "params" => params
        },
        tags: ["document_job"]
      }) do
    Logger.info("Job starting for running the document build...")

    start_time = Timex.now()

    Documents.update_build_history(build_history, %{status: "executing"})

    case Documents.build_doc(instance, layout) do
      {_, 0} ->
        Logger.info("Document build successful!")

        Documents.update_build_history(build_history, %{
          status: "success",
          start_time: start_time,
          end_time: Timex.now(),
          exit_code: 0
        })

        Documents.create_version(user, instance, params, :build)

      {_, exit_code} ->
        Logger.error("Document build failed with exit code #{exit_code}")

        Documents.update_build_history(build_history, %{
          status: "failed",
          start_time: start_time,
          end_time: Timex.now(),
          exit_code: exit_code
        })
    end

    Logger.info("Job end for running the document build.")
  end
end
