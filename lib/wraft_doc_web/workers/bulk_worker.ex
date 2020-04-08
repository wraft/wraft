defmodule WraftDocWeb.Worker.BulkWorker do
  use Oban.Worker, queue: :default
  @impl Oban.Worker
  import Ecto.Query
  alias WraftDoc.{Document}

  def perform(_args, _job) do
  end
end
