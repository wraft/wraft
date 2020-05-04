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

    mapping =
      mapping
      |> case do
        map when is_map(map) ->
          map

        string when is_binary(string) ->
          string |> Jason.decode!()
      end

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

    mapping =
      mapping
      |> case do
        map when is_map(map) ->
          map

        string when is_binary(string) ->
          string |> Jason.decode!()
      end

    current_user = Account.get_user_by_uuid(user_uuid)
    c_type = Document.get_content_type(c_type_uuid)
    Document.data_template_bulk_insert(current_user, c_type, mapping, path)
    IO.puts("Job end.!")
    :ok
  end
end
