defmodule WraftDoc.Schedulers.ContractEventHandler do
  @moduledoc """
  Handles Redis pub/sub events for contract expiry and reminders.
  Subscribes to contract-related events and processes them accordingly.
  """

  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_) do
    Redix.command!(:redix, ["PING"])
    {:ok, "Done"}
  end

  def handle_info({:redix_pubsub, _pid, _ref, :subscribed, %{channel: _channel}}, state) do
    IO.puts("Successfully subscribed to Redis Pub/Sub channel.")
    {:noreply, state}
  end

  def handle_info(
        {:redix_pubsub, _pid, _ref, :message, %{channel: "contract:expired", payload: payload}},
        state
      ) do
    IO.puts("Received contract expiry notification: #{payload}")

    # Here, you can trigger email notifications, update the DB, etc.
    {:noreply, state}
  end
end
