# defmodule WraftDoc.Search.TypesenseServer do
#   @moduledoc """
#   GenServer to handle Typesense operations for collections and documents.
#   """
#   use GenServer
#   alias WraftDoc.Search.Typesense

#   @operations [
#     :create_collection,
#     :create_document,
#     :get_document,
#     :update_document,
#     :delete_document,
#     :initialize
#   ]

#   def start_link(_opts) do
#     GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
#   end

#   def create_collection(schema), do: GenServer.call(__MODULE__, {:create_collection, schema})
#   def create_document(document), do: GenServer.call(__MODULE__, {:create_document, document})
#   def get_document(id, collection_name), do: GenServer.call(__MODULE__, {:get_document, id, collection_name})
#   def update_document(document), do: GenServer.call(__MODULE__, {:update_document, document})
#   def delete_document(id, collection_name), do: GenServer.call(__MODULE__, {:delete_document, id, collection_name})
#   def initialize, do: GenServer.call(__MODULE__, :initialize)

#   def init(state), do: {:ok, state}

#   def handle_call({:create_collection, schema}, _from, state) do
#     result = Typesense.create_collection(schema)
#     {:reply, result, state}
#   end

#   def handle_call({:create_document, document}, _from, state) do
#     result = Typesense.create_document(document)
#     {:reply, result, state}
#   end

#   def handle_call({:get_document, id, collection_name}, _from, state) do
#     result = Typesense.get_document(id, collection_name)
#     {:reply, result, state}
#   end

#   def handle_call({:update_document, document}, _from, state) do
#     result = Typesense.update_document(document)
#     {:reply, result, state}
#   end

#   def handle_call({:delete_document, id, collection_name}, _from, state) do
#     result = Typesense.delete_document(id, collection_name)
#     {:reply, result, state}
#   end

#   def handle_call(:initialize, _from, state) do
#     result = Typesense.initialize()
#     {:reply, result, state}
#   end
# end
defmodule WraftDoc.Search.TypesenseServer do
  @moduledoc """
  GenServer to handle Typesense operations for collections and documents.

  This server provides a centralized interface for all Typesense operations,
  including collection and document management.
  """

  use GenServer
  require Logger
  alias WraftDoc.Search.Typesense

  @type collection_schema :: map()
  @type document :: map()
  @type document_id :: String.t()
  @type collection_name :: String.t()
  @type result :: {:ok, term()} | {:error, term()}

  # Server name
  @server_name __MODULE__

  @doc """
  Starts the TypesenseServer with the given options.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, name: server_name(opts))
  end

  @doc """
  Creates a new collection with the given schema.
  """
  @spec create_collection(collection_schema()) :: result()
  def create_collection(schema) do
    GenServer.call(@server_name, {:create_collection, schema})
  end

  @doc """
  Creates a new document.
  """
  @spec create_document(document()) :: result()
  def create_document(document) do
    GenServer.call(@server_name, {:create_document, document})
  end

  @doc """
  Retrieves a document by its ID from the specified collection.
  """
  @spec get_document(document_id(), collection_name()) :: result()
  def get_document(id, collection_name) do
    GenServer.call(@server_name, {:get_document, id, collection_name})
  end

  @doc """
  Updates an existing document.
  """
  @spec update_document(document()) :: result()
  def update_document(document) do
    GenServer.call(@server_name, {:update_document, document})
  end

  @doc """
  Deletes a document by its ID from the specified collection.
  """
  @spec delete_document(document_id(), collection_name()) :: result()
  def delete_document(id, collection_name) do
    GenServer.call(@server_name, {:delete_document, id, collection_name})
  end

  @doc """
  Initializes the Typesense server and its collections.
  """
  @spec initialize() :: result()
  def initialize do
    GenServer.call(@server_name, :initialize)
  end

  @impl true
  def init(state) do
    Logger.info("Starting TypesenseServer...")
    {:ok, state}
  end

  @impl true
  def handle_call({:create_collection, schema}, _from, state) do
    Logger.debug("Creating collection with schema: #{inspect(schema)}")
    handle_typesense_operation(&Typesense.create_collection/1, [schema], state)
  end

  @impl true
  def handle_call({:create_document, document}, _from, state) do
    Logger.debug("Creating document: #{inspect(document)}")
    handle_typesense_operation(&Typesense.create_document/1, [document], state)
  end

  @impl true
  def handle_call({:get_document, id, collection_name}, _from, state) do
    Logger.debug("Getting document #{id} from collection #{collection_name}")
    handle_typesense_operation(&Typesense.get_document/2, [id, collection_name], state)
  end

  @impl true
  def handle_call({:update_document, document}, _from, state) do
    Logger.debug("Updating document: #{inspect(document)}")
    handle_typesense_operation(&Typesense.update_document/1, [document], state)
  end

  @impl true
  def handle_call({:delete_document, id, collection_name}, _from, state) do
    Logger.debug("Deleting document #{id} from collection #{collection_name}")
    handle_typesense_operation(&Typesense.delete_document/2, [id, collection_name], state)
  end

  @impl true
  def handle_call(:initialize, _from, state) do
    Logger.info("Initializing Typesense...")
    handle_typesense_operation(&Typesense.initialize/0, [], state)
  end

  defp handle_typesense_operation(operation, args, state) do
    result = apply(operation, args)

    case result do
      {:ok, _} = success ->
        {:reply, success, state}

      {:error, reason} = error ->
        Logger.error("Typesense operation failed: #{inspect(reason)}")
        {:reply, error, state}
    end
  end

  defp server_name(opts) do
    Keyword.get(opts, :name, @server_name)
  end
end
