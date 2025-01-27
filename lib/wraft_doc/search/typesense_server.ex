defmodule WraftDoc.Search.TypesenseServer do
  @moduledoc """
  GenServer to handle Typesense operations for collections and documents with error handling.
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
    Typesense.initialize()
    {:ok, state}
  end

  @impl true
  def handle_call({:create_collection, schema}, _from, state) do
    case Typesense.create_collection(schema) do
      {:ok, _result} ->
        {:reply, {:ok, %{message: "Collection created", schema: schema}}, state}

      {:error, reason} ->
        Logger.error("Failed to create collection: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:create_document, document}, _from, state) do
    case Typesense.create_document(document) do
      {:ok, _result} ->
        {:reply, {:ok, %{message: "Document created", document: document}}, state}

      {:error, reason} ->
        Logger.error("Failed to create document: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:get_document, id, collection_name}, _from, state) do
    case Typesense.get_document(id, collection_name) do
      {:ok, document} ->
        {:reply, {:ok, %{id: id, collection: collection_name, data: document}}, state}

      {:error, reason} ->
        Logger.error("Failed to get document #{id}: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:update_document, document}, _from, state) do
    case Typesense.update_document(document) do
      {:ok, _result} ->
        {:reply, {:ok, %{message: "Document updated", document: document}}, state}

      {:error, reason} ->
        Logger.error("Failed to update document: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:delete_document, id, collection_name}, _from, state) do
    case Typesense.delete_document(id, collection_name) do
      {:ok, _result} ->
        {:reply, {:ok, %{message: "Document deleted", id: id, collection: collection_name}},
         state}

      {:error, reason} ->
        Logger.error("Failed to delete document #{id}: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:initialize, _from, state) do
    case Typesense.initialize() do
      {:ok, _result} ->
        {:reply, {:ok, %{message: "Typesense initialized"}}, state}

      {:error, reason} ->
        Logger.error("Failed to initialize Typesense: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_info({:error, reason}, state) do
    Logger.error("Error in TypesenseServer: #{inspect(reason)}")
    {:noreply, state}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.warning("Unexpected message received: #{inspect(msg)}")
    {:noreply, state}
  end

  @impl true
  def terminate(reason, _state) do
    Logger.error("Typesense terminated: #{inspect(reason)}")
    :ok
  end
end
