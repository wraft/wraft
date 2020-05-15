defmodule WraftDocWeb.Worker.BulkWorker do
  use Oban.Worker, queue: :default
  @impl Oban.Worker
  alias WraftDoc.{Account, Document, Document.Pipeline.TriggerHistory, Enterprise}

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

    convert_map_to_trigger_struct(trigger)
    |> WraftDoc.PipelineRunner.call()
    |> IO.inspect(label: "pipe runner")

    IO.puts("Job end.!")
    :ok
  end

  defp convert_to_map(mapping) when is_map(mapping), do: mapping

  defp convert_to_map(mapping) when is_binary(mapping) do
    mapping |> Jason.decode!()
  end

  defp convert_map_to_trigger_struct(map) do
    map = for {k, v} <- map, into: %{}, do: {String.to_atom(k), v}
    struct(TriggerHistory, map)
  end
end
