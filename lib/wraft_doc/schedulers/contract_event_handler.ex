defmodule WraftDoc.Schedulers.ContractEventHandler do
  @moduledoc """
  Handles Redis pub/sub events for contract expiry and reminders.
  Subscribes to contract-related events and processes them accordingly.
  """

  use GenServer
  require Logger

  @channel "__keyevent@0__:expired"

  @spec start_link(any) :: {:ok, pid()} | {:error, term()}
  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @spec init(term) :: {:ok, term}
  def init(_) do
    Logger.info("Initializing ContractEventHandler...")

    Redix.command!(:redix, ["CONFIG", "SET", "notify-keyspace-events", "Ex"])

    {:ok, pubsub} = Redix.PubSub.start_link()
    {:ok, ref} = Redix.PubSub.subscribe(pubsub, @channel, self())

    {:ok, %{pubsub: pubsub, ref: ref}}
  end

  def handle_info({:redix_pubsub, _pid, _ref, :subscribed, %{channel: channel}}, state) do
    Logger.info("Subscribed to Redis channel: #{channel}")
    {:noreply, state}
  end

  def handle_info(
        {:redix_pubsub, _pid, _ref, :message,
         %{channel: @channel, payload: "contract:expiry:" <> contract_id}},
        state
      ) do
    Logger.info("Contract Expired: #{contract_id}")
    # Handle contract expiration (e.g., notify users, update DB)
    {:noreply, state}
  end

  def handle_info(
        {:redix_pubsub, _pid, _ref, :message,
         %{channel: @channel, payload: "contract:reminder:" <> contract_id}},
        state
      ) do
    Logger.info("Contract Reminder: #{contract_id}")
    # Handle contract reminder
    {:noreply, state}
  end
end
