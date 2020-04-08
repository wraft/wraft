defmodule WraftDocWeb.Worker.BulkWorker do
  use Oban.Worker, queue: :default
  @impl Oban.Worker
  import Ecto.Query
  alias WraftDoc.{Account, Document, Enterprise}

  def perform(
        %{
          "user_uuid" => user_uuid,
          "c_type_uuid" => c_type_uuid,
          "state_uuid" => state_uuid,
          "d_temp_uuid" => d_temp_uuid,
          "file" => path
        },
        _job
      ) do
    IO.puts("Job starting..")
    current_user = Account.get_user_by_uuid(user_uuid)
    c_type = Document.get_content_type(c_type_uuid)
    state = Enterprise.get_state(state_uuid)
    data_template = Document.get_d_template(d_temp_uuid)
    a = Document.bulk_doc_build(current_user, c_type, state, data_template, path)
    IO.inspect(a, label: "a")
    IO.puts("Job end.!")
    :ok
  end
end
