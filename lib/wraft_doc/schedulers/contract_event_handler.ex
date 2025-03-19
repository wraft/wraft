defmodule WraftDoc.Schedulers.ContractEventHandler do
  @moduledoc """
  Handles Redis pub/sub events for contract expiry and reminders.
  Subscribes to contract-related events and processes them accordingly.
  """
  use GenServer
  require Logger

  @channel "__keyevent@0__:expired"
  @expiry_prefix "document:expiry:"
  @reminder_prefix "document:reminder:"

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
         %{channel: @channel, payload: @expiry_prefix <> document_id}},
        state
      ) do
    Logger.info("Contract Expired: #{document_id}")
    # Handle contract expiration (e.g., notify users, update DB)
    {:noreply, state}
  end

  def handle_info(
        {:redix_pubsub, _pid, _ref, :message,
         %{channel: @channel, payload: @reminder_prefix <> document_id_reminder_id}},
        state
      ) do
    Logger.info("Contract Reminder: #{document_id_reminder_id}")
    # Handle contract reminder
    {:noreply, state}
  end

  @doc """
   Set Contract Expiry and reminder in redis for a document

    ## Parameters
    * `prefix` - prefix for the key
    * `document_id` - document id
    * `timestamp` - timestamp for expiry or reminder
    * `type` - type of expiry or reminder

    ## Examples
    iex> set_contract_events("contract:expiry", "document_id", 123456789, :expiry)
    {:ok, "OK"}

    iex> set_contract_events("contract:reminder", "document_id", 123456789, :reminder)
    {:ok, "OK"}
  """
  @spec set_contract_events(map(), DateTime.t()) :: {:ok, String.t()}
  def set_contract_events(
        %{document_id: document_id, reminder_id: reminder_id},
        reminder_timestamp
      ) do
    Redix.command(:redix, [
      "SET",
      "#{@reminder_prefix}#{document_id}:#{reminder_id}",
      "reminder",
      "EX",
      DateTime.to_unix(reminder_timestamp - DateTime.utc_now())
    ])
  end

  def set_contract_events(%{document_id: document_id}, expiry_timestamp) do
    Redix.command(:redix, [
      "SET",
      "#{@expiry_prefix}#{document_id}",
      "expired",
      "EX",
      DateTime.to_unix(expiry_timestamp - DateTime.utc_now())
    ])
  end
end
