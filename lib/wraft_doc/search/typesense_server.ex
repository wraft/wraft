defmodule WraftDoc.Search.TypesenseServer do
  @moduledoc """
  To handle the pubserver operations for typesense
  """
  use GenServer
  alias Phoenix.PubSub
  alias WraftDoc.Search.Typesense
  @pubsub WraftDoc.PubSub
  @topic "typesense:operations"

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(state) do
    :ok = PubSub.subscribe(@pubsub, @topic)
    {:ok, state}
  end

  def handle_info({operation, document} = _message, state)
      when operation in [
             :index_document,
             :create_document,
             :update_document,
             :get_document,
             :create_collection
           ] do
    apply(Typesense, operation, [document])
    {:noreply, state}
  end

  def handle_info({:delete_document, id, collection_name}, state) do
    Typesense.delete_document(id, collection_name)
    {:noreply, state}
  end

  def handle_info({:search, collection, query, caller}, state) do
    result = Typesense.search(collection, query)
    send(caller, {:search_result, result})
    {:noreply, state}
  end
end
