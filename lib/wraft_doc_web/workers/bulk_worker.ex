defmodule WraftDocWeb.Worker.BulkWorker do
  use Oban.Worker, queue: :default
  @impl Oban.Worker
  alias WraftDoc.{Repo, Account, Document, Document.Pipeline.TriggerHistory, Enterprise}
  alias Opus.PipelineError

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

    mapping = mapping |> convert_to_map()
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
    mapping = mapping |> convert_to_map()
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
    mapping = mapping |> convert_to_map()
    current_user = Account.get_user_by_uuid(user_uuid)
    Document.block_template_bulk_insert(current_user, mapping, path)
    IO.puts("Job end.!")
    :ok
  end

  def perform(%{"uuid" => _, "data" => _, "meta" => _, "pipeline_id" => _} = trigger, %{
        tags: ["pipeline_job"]
      }) do
    IO.puts("Job starting..")
    state = TriggerHistory.states()[:executing]

    convert_map_to_trigger_struct(trigger)
    |> update_trigger_history(%{state: state})
    |> WraftDoc.PipelineRunner.call()
    |> handle_exceptions()

    IO.puts("Job end.!")
    :ok
  end

  defp convert_to_map(mapping) when is_map(mapping), do: mapping

  defp convert_to_map(mapping) when is_binary(mapping) do
    mapping |> Jason.decode!()
  end

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

    update_trigger_history_state_and_meta(trigger, state, %{
      info: :values_unavailable,
      stage: stage
    })

    IO.puts("Required values not provided. Pipeline execution is now pending.")
  end

  defp handle_exceptions(
         {:error, %PipelineError{error: :pipeline_not_found, input: trigger, stage: stage}}
       ) do
    state = TriggerHistory.states()[:failed]

    update_trigger_history_state_and_meta(trigger, state, %{
      info: :pipeline_not_found,
      stage: stage
    })

    IO.puts("Pipeline not found. Pipeline execution failed.")
  end

  defp handle_exceptions(
         {:error, %PipelineError{error: :instance_failed, input: trigger, stage: stage}}
       ) do
    state = TriggerHistory.states()[:failed]
    update_trigger_history_state_and_meta(trigger, state, %{info: :instance_failed, stage: stage})
    IO.puts("Instance creation failed. Pipeline execution failed.")
  end

  defp handle_exceptions({:ok, %{trigger: trigger, failed_builds: failed_builds, stage: stage}}) do
    state = TriggerHistory.states()[:partially_completed]

    update_trigger_history_state_and_meta(trigger, state, %{
      info: "some_builds_failed",
      failed_builds: failed_builds,
      stage: stage
    })

    IO.puts("Pipeline partially completed.! Some builds failed.!")
  end

  defp handle_exceptions({:ok, %{trigger: trigger}}) do
    state = TriggerHistory.states()[:success]
    update_trigger_history(trigger, %{state: state})
    IO.puts("Pipeline completed succesfully.!")
  end

  # Update state and meta of a trigger history
  @spec update_trigger_history_state_and_meta(TriggerHistory.t(), integer, map) ::
          TriggerHistory.t()
  defp update_trigger_history_state_and_meta(trigger, state, meta) do
    key = Timex.now() |> DateTime.to_iso8601()
    meta = trigger.meta |> Map.put(key, meta)
    params = %{state: state, meta: meta}
    trigger |> update_trigger_history(params)
  end

  # Update a trigger history
  @spec update_trigger_history(TriggerHistory.t(), map) :: TriggerHistory.t()
  defp update_trigger_history(trigger, params) do
    trigger |> TriggerHistory.update_changeset(params) |> Repo.update!()
  end
end
