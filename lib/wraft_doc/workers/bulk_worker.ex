defmodule WraftDoc.Workers.BulkWorker do
  @moduledoc """
  Oban worker for bulk building of docs.
  """
  use Oban.Worker, queue: :events, max_attempts: 1
  require Logger

  alias Opus.PipelineError
  alias WraftDoc.Account
  alias WraftDoc.BlockTemplates
  alias WraftDoc.Client.Minio.DownloadError
  alias WraftDoc.ContentTypes
  alias WraftDoc.DataTemplates
  alias WraftDoc.Documents
  alias WraftDoc.Enterprise
  alias WraftDoc.Notifications.Delivery
  alias WraftDoc.Pipelines.TriggerHistories.TriggerHistory
  alias WraftDoc.Repo

  @impl Oban.Worker
  def perform(%Job{
        args: %{
          "user_uuid" => user_uuid,
          "c_type_uuid" => c_type_uuid,
          "state_uuid" => state_uuid,
          "d_temp_uuid" => d_temp_uuid,
          "mapping" => mapping,
          "file" => path
        }
      }) do
    Logger.info("Job starting for bulk doc build..")

    mapping = convert_to_map(mapping)
    current_user = Account.get_user_by_uuid(user_uuid)
    c_type = ContentTypes.get_content_type(current_user, c_type_uuid)
    state = Enterprise.get_state(current_user, state_uuid)
    data_template = DataTemplates.get_data_template(current_user, d_temp_uuid)
    Documents.bulk_doc_build(current_user, c_type, state, data_template, mapping, path)
    Logger.info("Job end for bulk doc build.!")
    :ok
  end

  def perform(%Job{
        args: %{
          "user_uuid" => user_uuid,
          "c_type_uuid" => c_type_uuid,
          "mapping" => mapping,
          "file" => path
        }
      }) do
    Logger.info("Job starting for bulk data template insertion..")
    mapping = convert_to_map(mapping)
    current_user = Account.get_user_by_uuid(user_uuid)
    c_type = ContentTypes.get_content_type(current_user, c_type_uuid)
    DataTemplates.insert_data_template_bulk(current_user, c_type, mapping, path)
    Logger.info("Job end for bulk data template insertion.!")
    :ok
  end

  def perform(%Job{
        args: %{"user_uuid" => user_uuid, "mapping" => mapping, "file" => path},
        tags: ["block template"]
      }) do
    Logger.info("Job starting for bulk block template insertion..")
    mapping = convert_to_map(mapping)
    current_user = Account.get_user_by_uuid(user_uuid)
    BlockTemplates.block_template_bulk_insert(current_user, mapping, path)
    Logger.info("Job end for bulk block template insertion.!")
    :ok
  end

  def perform(%Job{
        args: %{"current_user" => current_user, "trigger_history" => trigger},
        tags: ["pipeline_job"]
      }) do
    Logger.info("Job starting for running the pipeline...")
    start_time = Timex.now()
    state = TriggerHistory.states()[:executing]

    trigger
    |> convert_map_to_trigger_struct()
    |> trigger_start_update(%{state: state, start_time: start_time})
    |> WraftDoc.PipelineRunner.call()
    |> handle_exceptions(current_user)
    |> trigger_end_update()

    Logger.info("Job end for running the pipeline.!")
  end

  defp convert_to_map(mapping) when is_map(mapping), do: mapping

  defp convert_to_map(mapping) when is_binary(mapping), do: Jason.decode!(mapping)

  # Convert a map to TriggerHistory struct
  @spec convert_map_to_trigger_struct(map) :: TriggerHistory.t()
  defp convert_map_to_trigger_struct(map) do
    map = for {k, v} <- map, into: %{}, do: {String.to_atom(k), v}
    struct(TriggerHistory, map)
  end

  # Handle exceptions/responses returned from the PipelineRunner
  @spec handle_exceptions(tuple(), User.t()) :: any()
  defp handle_exceptions(
         {:error,
          %PipelineError{error: :form_mapping_not_complete, input: trigger, stage: stage}},
         _current_user
       ) do
    state = TriggerHistory.states()[:failed]

    trigger =
      update_trigger_history_state_and_error(trigger, state, %{
        info: "Form Mapping Not Complete",
        message: "Please complete the form mapping and try again.",
        stage: stage
      })

    Logger.error("Form mapping not complete. Pipeline execution failed.")
    trigger
  end

  defp handle_exceptions(
         {:error, %PipelineError{error: :pipeline_not_found, input: trigger, stage: stage}},
         _current_user
       ) do
    state = TriggerHistory.states()[:failed]

    trigger =
      update_trigger_history_state_and_error(trigger, state, %{
        info: "Pipeline Not Found",
        message:
          "The pipeline you're trying to run does not exist. Please double-check the pipeline name and try again.",
        stage: stage
      })

    Logger.error("Pipeline not found. Pipeline execution failed.")
    trigger
  end

  defp handle_exceptions(
         {:error, %PipelineError{error: :instance_failed, input: trigger, stage: stage}},
         _current_user
       ) do
    state = TriggerHistory.states()[:failed]

    trigger =
      update_trigger_history_state_and_error(trigger, state, %{
        info: "Document Generation Failed",
        message:
          "There was an error creating the document instance. Please check the input data and try again.",
        stage: stage
      })

    Logger.error("Instance creation failed. Pipeline execution failed.")
    trigger
  end

  defp handle_exceptions(
         {:error,
          %PipelineError{error: %DownloadError{message: message}, input: trigger, stage: stage}},
         _current_user
       ) do
    state = TriggerHistory.states()[:failed]

    trigger =
      update_trigger_history_state_and_error(trigger, state, %{
        info: "Download Error",
        message: message,
        stage: stage
      })

    Logger.error("Instance creation failed. Pipeline execution failed.")
    trigger
  end

  defp handle_exceptions(
         {:error,
          %PipelineError{error: %InvalidJsonError{message: message}, input: trigger, stage: stage}},
         _current_user
       ) do
    state = TriggerHistory.states()[:failed]

    trigger =
      update_trigger_history_state_and_error(trigger, state, %{
        info: "Invalid JSON Error",
        message: message,
        stage: stage
      })

    Logger.error("Invalid JSON error. Pipeline execution failed.")
    trigger
  end

  defp handle_exceptions(
         {:ok, %{trigger: trigger, failed_builds: [], zip_file: zip_file}},
         current_user
       ) do
    state = TriggerHistory.states()[:success]
    trigger = update_trigger_history(trigger, %{state: state, zip_file: zip_file})

    Task.start(fn ->
      trigger.creator_id
      |> Account.get_user()
      |> Map.put(:current_org_id, current_user["current_org_id"])
      |> Delivery.dispatch("pipeline.build_success", %{
        channel: :user_notification,
        channel_id: trigger.creator_id,
        metadata: %{
          type: "pipeline",
          user_id: trigger.creator_id,
          pipeline_id: trigger.pipeline_id
        }
      })
    end)

    Logger.info("Pipeline completed succesfully.!")
    trigger
  end

  defp handle_exceptions(
         {:ok, %{trigger: trigger, failed_builds: failed_builds, zip_file: zip_file}},
         current_user
       ) do
    state = TriggerHistory.states()[:partially_completed]

    trigger =
      update_trigger_history_state_and_error(trigger, state, %{
        info: "Builds Failed",
        message: "Some builds failed. Please check the logs for more information.",
        failed_builds: failed_builds,
        zip_file: zip_file
      })

    Task.start(fn ->
      trigger.creator_id
      |> Account.get_user()
      |> Map.put(:current_org_id, current_user["current_org_id"])
      |> Delivery.dispatch("pipeline.build_failed", %{
        channel: :user_notification,
        channel_id: trigger.creator_id,
        metadata: %{
          type: "pipeline",
          user_id: trigger.creator_id,
          pipeline_id: trigger.pipeline_id
        }
      })
    end)

    Logger.error("Pipeline partially completed.! Some builds failed.!")
    trigger
  end

  # Update state and error of a trigger history
  @spec update_trigger_history_state_and_error(TriggerHistory.t(), integer, map) ::
          TriggerHistory.t()
  defp update_trigger_history_state_and_error(trigger, state, error) do
    failure_time = DateTime.to_iso8601(Timex.now())
    error = Map.put(error, :failure_time, failure_time)
    update_trigger_history(trigger, %{state: state, error: error})
  end

  # Update trigger history on start
  defp trigger_start_update(trigger, params) do
    trigger |> TriggerHistory.trigger_start_changeset(params) |> Repo.update!()
  end

  # Update a trigger history
  defp update_trigger_history(trigger, params) do
    trigger |> TriggerHistory.update_changeset(params) |> Repo.update!()
  end

  # Update trigger function, called after a trigger is run.
  defp trigger_end_update(trigger) do
    trigger |> TriggerHistory.trigger_end_changeset(%{end_time: Timex.now()}) |> Repo.update!()
  end
end
