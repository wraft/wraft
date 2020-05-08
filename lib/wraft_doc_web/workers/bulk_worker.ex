defmodule WraftDocWeb.Worker.BulkWorker do
  use Oban.Worker, queue: :default
  @impl Oban.Worker
  alias WraftDoc.{Account, Document, Enterprise}

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
    c_type = Document.get_content_type(c_type_uuid)
    state = Enterprise.get_state(state_uuid)
    data_template = Document.get_d_template(d_temp_uuid)
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
    c_type = Document.get_content_type(c_type_uuid)
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

  defp convert_to_map(mapping) when is_map(mapping), do: mapping

  defp convert_to_map(mapping) when is_binary(mapping) do
    mapping |> Jason.decode!()
  end
end
