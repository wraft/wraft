defmodule WraftDoc.Search.Broadcaster do
  @moduledoc """
  Where nature of pub server is defined for typesense
  """
  alias Phoenix.PubSub
  @pubsub WraftDoc.PubSub
  @topic "typesense:operations"
  @timeout 5000
  @operations [
    :index_document,
    :create_document,
    :update_document,
    :get_document,
    :create_collection
  ]

  for operation <- @operations do
    def unquote(operation)(document) do
      PubSub.broadcast(@pubsub, @topic, {unquote(operation), document})
    end
  end

  # Special case for delete_document with two parameters
  def delete_document(id, collection_name) do
    PubSub.broadcast(@pubsub, @topic, {:delete_document, id, collection_name})
  end

  def search(collection, query) do
    PubSub.broadcast(@pubsub, @topic, {:search, collection, query, self()})

    receive do
      {:search_result, result} -> result
    after
      @timeout -> {:error, :timeout}
    end
  end
end
