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
  @spec initialize() :: :ok
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
      :ok ->
        Logger.info("Typesense initialized successfully.")

      {:ok, _} ->
        Logger.info("Typesense initialized successfully.")

      {:error, reason} ->
        Logger.warning("Typesense initialization failed: #{inspect(reason)}")

        Logger.warning(
          "Typesense service may not be available. Search functionality will be limited."
        )

      unexpected ->
        Logger.warning("Unexpected Typesense response: #{inspect(unexpected)}")
    end
  rescue
    exception ->
      case exception do
        %FunctionClauseError{function: :put_header, arity: 3} ->
          Logger.warning(
            "Typesense initialization failed due to Req library compatibility issue."
          )

          Logger.warning(
            "Typesense service may not be available. Search functionality will be limited."
          )

        _ ->
          Logger.warning(
            "Typesense initialization exception: #{Exception.format(:error, exception)}"
          )

          Logger.warning(
            "Typesense service may not be available. Search functionality will be limited."
          )
      end
  catch
    type, value ->
      Logger.warning("Caught #{type} during Typesense initialization: #{inspect(value)}")

      Logger.warning(
        "Typesense service may not be available. Search functionality will be limited."
      )
  end

  @impl true
  def handle_cast({:create_document, document}, state) do
    try do
      case Typesense.create_document(document) do
        {:ok, _result} ->
          Logger.debug("Document created successfully")

        {:error, reason} ->
          Logger.warning("Failed to create document: #{inspect(reason)}")
      end
    rescue
      error ->
        case error do
          %Req.TransportError{reason: :econnrefused} ->
            Logger.warning(
              "Typesense server unavailable (connection refused) - document creation skipped"
            )

          _ ->
            Logger.warning("Typesense create failed with exception: #{inspect(error)}")
        end
    catch
      :exit, reason ->
        Logger.warning("Typesense create exited: #{inspect(reason)}")

      type, value ->
        Logger.warning("Typesense create caught #{type}: #{inspect(value)}")
    end

    {:noreply, state}
  end

  @impl true
  def handle_cast({:update_document, document}, state) do
    try do
      case Typesense.update_document(document) do
        {:ok, _result} ->
          Logger.debug("Document updated successfully")

        {:error, reason} ->
          Logger.warning("Failed to update document: #{inspect(reason)}")
      end
    rescue
      error ->
        case error do
          %Req.TransportError{reason: :econnrefused} ->
            Logger.warning(
              "Typesense server unavailable (connection refused) - document update skipped"
            )

          _ ->
            Logger.warning("Typesense update failed with exception: #{inspect(error)}")
        end
    catch
      :exit, reason ->
        Logger.warning("Typesense update exited: #{inspect(reason)}")

      type, value ->
        Logger.warning("Typesense update caught #{type}: #{inspect(value)}")
    end

    {:noreply, state}
  end

  @impl true
  def handle_cast({:delete_document, id, collection_name}, state) do
    try do
      case Typesense.delete_document(id, collection_name) do
        {:ok, _result} ->
          Logger.debug("Document deleted successfully")

        {:error, reason} ->
          Logger.warning("Failed to delete document #{id}: #{inspect(reason)}")
      end
    rescue
      error ->
        case error do
          %Req.TransportError{reason: :econnrefused} ->
            Logger.warning(
              "Typesense server unavailable (connection refused) - document deletion skipped"
            )

          _ ->
            Logger.warning("Typesense delete failed with exception: #{inspect(error)}")
        end
    catch
      :exit, reason ->
        Logger.warning("Typesense delete exited: #{inspect(reason)}")

      type, value ->
        Logger.warning("Typesense delete caught #{type}: #{inspect(value)}")
    end

    {:noreply, state}
  end

  @impl true
  def handle_cast({:create_collection, schema}, state) do
    case Typesense.create_collection(schema) do
      {:ok, _result} ->
        Logger.info("Collection created successfully.")

      {:error, reason} ->
        Logger.warning("Failed to create collection: #{inspect(reason)}")
    end

    {:noreply, state}
  end

  @impl true
  def handle_cast(:initialize, state) do
    try do
      case Typesense.initialize() do
        {:ok, _result} ->
          Logger.info("Typesense initialized successfully.")

        :ok ->
          Logger.info("Typesense initialized successfully (no extra data).")

        {:error, reason} ->
          Logger.warning("Failed to initialize Typesense: #{inspect(reason)}")

          Logger.warning(
            "Typesense service may not be available. Search functionality will be limited."
          )
      end
    rescue
      exception ->
        case exception do
          %FunctionClauseError{function: :put_header, arity: 3} ->
            Logger.warning(
              "Typesense initialization failed due to Req library compatibility issue."
            )

            Logger.warning(
              "Typesense service may not be available. Search functionality will be limited."
            )

          _ ->
            Logger.warning(
              "Typesense initialization exception: #{Exception.format(:error, exception)}"
            )

            Logger.warning(
              "Typesense service may not be available. Search functionality will be limited."
            )
        end
    end

    {:noreply, state}
  end

  @impl true
  def handle_info({:error, reason}, state) do
    Logger.warning("Error in TypesenseServer: #{inspect(reason)}")
    {:noreply, state}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.warning("Unexpected message received: #{inspect(msg)}")
    {:noreply, state}
  end

  @impl true
  def terminate(reason, _state) do
    Logger.warning("Typesense terminated: #{inspect(reason)}")
    :ok
  end
end
