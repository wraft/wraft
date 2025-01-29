defmodule WraftDoc.Search.TypesenseServer do
  @moduledoc """
  A GenServer that handles communication with Typesense for managing collections and documents.
  It provides operations to create, update, retrieve, and delete documents asynchronously.
  """

  use GenServer
  require Logger
  alias WraftDoc.Search.Typesense

  @timeout :timer.seconds(30)

  # Public API

  @doc """
  Starts the TypesenseServer GenServer.
  Accepts options where you can specify a custom name.
  """
  @spec start_link(Keyword.t()) :: {:ok, pid()} | {:error, term()}
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Creates a new collection in Typesense using the provided schema.
  """
  @spec create_collection(module()) :: {:ok, map()} | {:error, term()}
  def create_collection(schema) do
    GenServer.call(__MODULE__, {:create_collection, schema}, @timeout)
  end

  @doc """
  Creates a new document asynchronously.
  """
  @spec create_document(map()) :: :ok
  def create_document(document) do
    GenServer.call(__MODULE__, {:create_document, document})
  end

  @doc """
  Retrieves a document by ID from a specific collection.
  """
  @spec get_document(binary(), binary()) :: {:ok, map()} | {:error, term()}
  def get_document(id, collection_name) when is_binary(id) and is_binary(collection_name) do
    GenServer.call(__MODULE__, {:get_document, id, collection_name}, @timeout)
  end

  @doc """
  Updates an existing document asynchronously.
  """
  @spec update_document(map()) :: :ok
  def update_document(document) do
    GenServer.call(__MODULE__, {:update_document, document})
  end

  @doc """
  Deletes a document by ID from a specific collection asynchronously.
  """
  def delete_document(id, collection_name) when is_binary(id) and is_binary(collection_name) do
    GenServer.call(__MODULE__, {:delete_document, id, collection_name})
  end

  # GenServer Callbacks

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
