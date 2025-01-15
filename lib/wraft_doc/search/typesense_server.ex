defmodule WraftDoc.Search.TypesenseServer do
  @moduledoc """
  GenServer to handle Typesense operations for collections and documents.
  """
  use GenServer
  require Logger
  alias WraftDoc.Search.Typesense

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def create_collection(schema) do
    GenServer.call(__MODULE__, {:create_collection, schema}, :timer.seconds(30))
  end

  def create_document(document) do
    GenServer.call(__MODULE__, {:create_document, document})
  end

  def get_document(id, collection_name) when is_binary(id) and is_binary(collection_name) do
    GenServer.call(__MODULE__, {:get_document, id, collection_name})
  end

  def update_document(document) do
    GenServer.call(__MODULE__, {:update_document, document})
  end

  def delete_document(id, collection_name) when is_binary(id) and is_binary(collection_name) do
    GenServer.call(__MODULE__, {:delete_document, id, collection_name})
  end

  @impl true
  def init(state) do
    Logger.info("Starting TypesenseServer...")
    {:ok, state}
  end

  @impl true
  def handle_call({:create_collection, schema}, _from, state) do
    Logger.debug("Creating collection with schema: #{inspect(schema)}")
    Typesense.create_collection(schema)
    result = {:ok, %{message: "Collection created", schema: schema}}
    {:reply, result, state}
  end

  @impl true
  def handle_call({:create_document, document}, _from, state) do
    Logger.debug("Creating document: #{inspect(document)}")
    Typesense.create_document(document)
    result = {:ok, %{message: "Document created", document: document}}
    {:reply, result, state}
  end

  @impl true
  def handle_call({:get_document, id, collection_name}, _from, state) do
    Logger.debug("Getting document #{id} from collection #{collection_name}")
    Typesense.get_document(id, collection_name)
    result = {:ok, %{id: id, collection: collection_name, data: %{}}}
    {:reply, result, state}
  end

  @impl true
  def handle_call({:update_document, document}, _from, state) do
    Logger.debug("Updating document: #{inspect(document)}")
    Typesense.update_document(document)
    result = {:ok, %{message: "Document updated", document: document}}
    {:reply, result, state}
  end

  @impl true
  def handle_call({:delete_document, id, collection_name}, _from, state) do
    Logger.debug("Deleting document #{id} from collection #{collection_name}")
    Typesense.delete_document(id, collection_name)
    result = {:ok, %{message: "Document deleted", id: id, collection: collection_name}}
    {:reply, result, state}
  end

  @impl true
  def handle_call(:initialize, _from, state) do
    Logger.info("Initializing Typesense...")
    Typesense.initialize()
    result = {:ok, %{message: "Typesense initialized"}}
    {:reply, result, state}
  end

  @impl true
  def handle_info({:error, reason}, state) do
    Logger.error("Error in TypesenseServer: #{inspect(reason)}")
    {:noreply, state}
  end
end
