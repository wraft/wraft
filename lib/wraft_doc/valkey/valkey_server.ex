defmodule WraftDoc.Valkey.ValkeyServer do
  @moduledoc """
  Manages the Valkey connection for the application.
  Valkey is used for storing contract reminders and other time-sensitive data.
  Uses Redix as the client to connect to Valkey (which is Redis-compatible).
  """
  use GenServer
  require Logger

  @valkey_pool_size 10
  @valkey_timeout 5000

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @impl true
  def init(_) do
    # Get configuration from the application environmen
    config = Application.get_env(:wraft_doc, :valkey) || %{}

    # Start the connection pool
    {:ok, conn} = start_connection(config)

    # Return the state with connection
    {:ok, %{conn: conn}}
  end

  @doc """
  Store a key-value pair in Valkey with an optional expiry time
  """
  def set(key, value, options \\ []) do
    GenServer.call(__MODULE__, {:set, key, value, options})
  end

  @doc """
  Get a value from Valkey
  """
  def get(key) do
    GenServer.call(__MODULE__, {:get, key})
  end

  @doc """
  Delete a key from Valkey
  """
  def del(key) do
    GenServer.call(__MODULE__, {:del, key})
  end

  @doc """
  Get all keys matching a pattern
  """
  def keys(pattern) do
    GenServer.call(__MODULE__, {:keys, pattern})
  end

  @impl true
  def handle_call({:set, key, value, options}, _from, %{conn: conn} = state) do
    result =
      try do
        command = ["SET", key, value]

        # Add expiry if provided
        command =
          case Keyword.get(options, :ex) do
            nil -> command
            ttl -> command ++ ["EX", to_string(ttl)]
          end

        # Execute SET command
        Redix.command(conn, command)
      rescue
        e ->
          Logger.error("Failed to set key in Valkey: #{inspect(e)}")
          {:error, :valkey_error}
      end

    {:reply, result, state}
  end

  @impl true
  def handle_call({:get, key}, _from, %{conn: conn} = state) do
    result =
      try do
        Redix.command(conn, ["GET", key])
      rescue
        e ->
          Logger.error("Failed to get key from Valkey: #{inspect(e)}")
          {:error, :valkey_error}
      end

    {:reply, result, state}
  end

  @impl true
  def handle_call({:del, key}, _from, %{conn: conn} = state) do
    result =
      try do
        Redix.command(conn, ["DEL", key])
      rescue
        e ->
          Logger.error("Failed to delete key from Valkey: #{inspect(e)}")
          {:error, :valkey_error}
      end

    {:reply, result, state}
  end

  @impl true
  def handle_call({:keys, pattern}, _from, %{conn: conn} = state) do
    result =
      try do
        Redix.command(conn, ["KEYS", pattern])
      rescue
        e ->
          Logger.error("Failed to get keys from Valkey: #{inspect(e)}")
          {:error, :valkey_error}
      end

    {:reply, result, state}
  end

  defp start_connection(config) do
    # Get connection details
    host = Map.get(config, :host, "localhost")
    port = Map.get(config, :port, 6379)
    password = Map.get(config, :password)
    database = Map.get(config, :database, 0)

    # Build connection options
    options = [
      host: host,
      port: port,
      database: database,
      timeout: @valkey_timeout,
      pool_size: @valkey_pool_size
    ]

    # Add password if provided
    options = if password, do: Keyword.put(options, :password, password), else: options

    # Start the connection
    case Redix.start_link(options) do
      {:ok, conn} ->
        Logger.info("Connected to Valkey at #{host}:#{port}")
        {:ok, conn}

      {:error, reason} ->
        Logger.error("Failed to connect to Valkey: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
