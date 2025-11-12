defmodule WraftDoc.Workers.TokenRefreshWorker do
  @moduledoc """
  Worker to refresh expiring tokens for integrations.
  """

  use Oban.Worker, queue: :integrations

  alias WraftDoc.Integrations
  require Logger

  @impl true
  def perform(_job) do
    Integrations.refresh_expiring_tokens()
    :ok
  end
end
