defmodule WraftDoc.Search.TypesenseServer do
  @moduledoc """
  A GenServer that handles communication with Typesense for managing collections and documents.
  It provides operations to create, update, retrieve, and delete documents asynchronously.
  """

  use GenServer
  require Logger
  alias WraftDoc.Search.Typesense

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
  Asynchronously initializes the Typesense connection.
  """
  @spec initialize() :: :ok | {:error, :unauthorized}
  def initialize do
    GenServer.cast(__MODULE__, :initialize)
  end

  @doc """
  Asynchronously creates a collection in Typesense with given schema.
  """
  @spec create_collection(module()) :: :ok
  def create_collection(schema) do
    GenServer.cast(__MODULE__, {:create_collection, schema})
  end

  @doc """
  Creates a new document asynchronously.
  """
  @spec create_document(map()) :: :ok
  def create_document(document) do
    GenServer.cast(__MODULE__, {:create_document, document})
  end

  @doc """
  Updates an existing document asynchronously.
  """
  @spec update_document(map()) :: :ok
  def update_document(document) do
    GenServer.cast(__MODULE__, {:update_document, document})
  end

  @doc """
  Deletes a document by ID from a specific collection asynchronously.
  """
  def delete_document(id, collection_name) when is_binary(id) and is_binary(collection_name) do
    GenServer.cast(__MODULE__, {:delete_document, id, collection_name})
  end

  # GenServer Callbacks
  @impl true
  def init(state) do
    Logger.info("Starting TypesenseServer")
    Task.start(fn -> handle_initialization() end)
    {:ok, state}
  end

  defp handle_initialization do
    case Typesense.initialize() do
      :ok -> Logger.info("Typesense initialized successfully.")
      {:ok, _} -> Logger.info("Typesense initialized successfully.")
      {:error, reason} -> Logger.error("Failed to initialize Typesense: #{inspect(reason)}")
      unexpected -> Logger.warning("Unexpected Typesense response: #{inspect(unexpected)}")
    end
  rescue
    exception -> Logger.error("Initialization exception: #{Exception.format(:error, exception)}")
  catch
    type, value -> Logger.error("Caught #{type}: #{inspect(value)}")
  end

  @impl true
  def handle_cast({:create_document, document}, state) do
    case Typesense.create_document(document) do
      {:ok, _result} ->
        Logger.debug("Document created successfully")

      {:error, reason} ->
        Logger.error("Failed to create document: #{inspect(reason)}")
    end

    {:noreply, state}
  end

  @impl true
  def handle_cast({:update_document, document}, state) do
    case Typesense.update_document(document) do
      {:ok, _result} ->
        Logger.debug("Document updated successfully")

      {:error, reason} ->
        Logger.error("Failed to update document: #{inspect(reason)}")
    end

    {:noreply, state}
  end

  @impl true
  def handle_cast({:delete_document, id, collection_name}, state) do
    case Typesense.delete_document(id, collection_name) do
      {:ok, _result} ->
        Logger.debug("Document deleted successfully")

      {:error, reason} ->
        Logger.error("Failed to delete document #{id}: #{inspect(reason)}")
    end

    {:noreply, state}
  end

  @impl true
  def handle_cast({:create_collection, schema}, state) do
    case Typesense.create_collection(schema) do
      {:ok, _result} ->
        Logger.info("Collection created successfully.")

      {:error, reason} ->
        Logger.error("Failed to create collection: #{inspect(reason)}")
    end

    {:noreply, state}
  end

  @impl true
  def handle_cast(:initialize, state) do
    case Typesense.initialize() do
      {:ok, _result} ->
        Logger.info("Typesense initialized successfully.")

      :ok ->
        Logger.info("Typesense initialized successfully (no extra data).")

      {:error, reason} ->
        Logger.error("Failed to initialize Typesense: #{inspect(reason)}")
    end

    {:noreply, state}
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
