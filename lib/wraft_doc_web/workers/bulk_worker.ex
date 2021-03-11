defmodule WraftDocWeb.Worker.BulkWorker do
  @moduledoc """
  Oban worker for bulk building of docs.
  """
  use Oban.Worker, queue: :default
  @impl Oban.Worker
  alias Opus.PipelineError
  alias WraftDoc.{Account, Document, Document.Pipeline.TriggerHistory, Enterprise, Repo}

  def perform(
        %{
          "user_uuid" => user_uuid,
          "c_type_uuid" => c_type_uuid,
          "state_uuid" => state_uuid,
          "d_temp_uuid" => d_temp_uuid,
          "mapping" => mapping,
          "file" => path
        },
        _job
      ) do
    IO.puts("Job starting..")

    mapping = convert_to_map(mapping)
    current_user = Account.get_user_by_uuid(user_uuid)
    c_type = Document.get_content_type(current_user, c_type_uuid)
    state = Enterprise.get_state(current_user, state_uuid)
    data_template = Document.get_d_template(current_user, d_temp_uuid)
    Document.bulk_doc_build(current_user, c_type, state, data_template, mapping, path)
    IO.puts("Job end.!")
    :ok
  end

  def perform(
        %{
          "user_uuid" => user_uuid,
          "c_type_uuid" => c_type_uuid,
          "mapping" => mapping,
          "file" => path
        },
        _job
      ) do
    IO.puts("Job starting..")
    mapping = convert_to_map(mapping)
    current_user = Account.get_user_by_uuid(user_uuid)
    c_type = Document.get_content_type(current_user, c_type_uuid)
    Document.data_template_bulk_insert(current_user, c_type, mapping, path)
    IO.puts("Job end.!")
    :ok
  end

  def perform(%{"user_uuid" => user_uuid, "mapping" => mapping, "file" => path}, %{
        tags: ["block template"]
      }) do
    IO.puts("Job starting..")
    mapping = convert_to_map(mapping)
    current_user = Account.get_user_by_uuid(user_uuid)
    Document.block_template_bulk_insert(current_user, mapping, path)
    IO.puts("Job end.!")
    :ok
  end

  def perform(trigger, %{tags: ["pipeline_job"]}) do
    IO.puts("Job starting..")
    start_time = Timex.now()
    state = TriggerHistory.states()[:executing]

    trigger
    |> convert_map_to_trigger_struct()
    |> update_trigger_history(%{state: state, start_time: start_time})
    |> WraftDoc.PipelineRunner.call()
    |> handle_exceptions()
    |> trigger_end_update()

    IO.puts("Job end.!")
    :ok
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
  @spec handle_exceptions(tuple) :: any
  defp handle_exceptions(
         {:error, %PipelineError{error: :values_unavailable, input: trigger, stage: stage}}
       ) do
    state = TriggerHistory.states()[:pending]

    trigger =
      update_trigger_history_state_and_error(trigger, state, %{
        info: :values_unavailable,
        stage: stage
      })

    IO.puts("Required values not provided. Pipeline execution is now pending.")
    trigger
  end

  defp handle_exceptions(
         {:error, %PipelineError{error: :pipeline_not_found, input: trigger, stage: stage}}
       ) do
    state = TriggerHistory.states()[:failed]

    trigger =
      update_trigger_history_state_and_error(trigger, state, %{
        info: :pipeline_not_found,
        stage: stage
      })

    IO.puts("Pipeline not found. Pipeline execution failed.")
    trigger
  end

  defp handle_exceptions(
         {:error, %PipelineError{error: :instance_failed, input: trigger, stage: stage}}
       ) do
    state = TriggerHistory.states()[:failed]

    trigger =
      update_trigger_history_state_and_error(trigger, state, %{
        info: :instance_failed,
        stage: stage
      })

    IO.puts("Instance creation failed. Pipeline execution failed.")
    trigger
  end

  defp handle_exceptions(
         {:ok, %{trigger: trigger, failed_builds: failed_builds, zip_file: zip_file}}
       ) do
    state = TriggerHistory.states()[:partially_completed]

    trigger =
      update_trigger_history_state_and_error(trigger, state, %{
        info: "some_builds_failed",
        failed_builds: failed_builds,
        zip_file: zip_file
      })

    IO.puts("Pipeline partially completed.! Some builds failed.!")
    trigger
  end

  defp handle_exceptions({:ok, %{trigger: trigger, zip_file: zip_file}}) do
    state = TriggerHistory.states()[:success]
    trigger = update_trigger_history(trigger, %{state: state, zip_file: zip_file})
    IO.puts("Pipeline completed succesfully.!")
    trigger
  end

  # Update state and error of a trigger history
  @spec update_trigger_history_state_and_error(TriggerHistory.t(), integer, map) ::
          TriggerHistory.t()
  defp update_trigger_history_state_and_error(trigger, state, error) do
    key = DateTime.to_iso8601(Timex.now())
    error = Map.put(trigger.error, key, error)
    update_trigger_history(trigger, %{state: state, error: error})
  end

  # Update a trigger history
  @spec update_trigger_history(TriggerHistory.t(), map) :: TriggerHistory.t()
  defp update_trigger_history(trigger, params) do
    trigger |> TriggerHistory.update_changeset(params) |> Repo.update!()
  end

  # Update trigger function, called after a trigger is run.
  defp trigger_end_update(trigger) do
    trigger |> TriggerHistory.trigger_end_changeset(%{end_time: Timex.now()}) |> Repo.update!()
  end
end
