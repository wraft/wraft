defmodule WraftDoc.Schedulers.ValkeyServer do
  @moduledoc """
  Manages the Valkey connection for the application.
  Valkey is used for storing contract reminders and other time-sensitive data.
  Uses Redix as the client to connect to Valkey (which is Redis-compatible).
  """
  use GenServer
  require Logger

  @valkey_timeout 5000

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @impl true
  def init(_) do
    Application.get_env(:wraft_doc, :valkey, [])
    # Convert keyword list to map
    |> Enum.into(%{})
    |> start_connection()
    |> case do
      {:ok, conn} -> {:ok, %{conn: conn}}
      {:error, reason} -> {:stop, reason}
    end
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
    ["SET", key, value]
    |> maybe_add_expiry(options)
    |> execute_command(conn)
    |> reply_with_state(state)
  end

  @impl true
  def handle_call({:get, key}, _from, %{conn: conn} = state) do
    ["GET", key]
    |> execute_command(conn)
    |> reply_with_state(state)
  end

  @impl true
  def handle_call({:del, key}, _from, %{conn: conn} = state) do
    ["DEL", key]
    |> execute_command(conn)
    |> reply_with_state(state)
  end

  @impl true
  def handle_call({:keys, pattern}, _from, %{conn: conn} = state) do
    ["KEYS", pattern]
    |> execute_command(conn)
    |> reply_with_state(state)
  end

  defp reply_with_state(result, state), do: {:reply, result, state}

  defp maybe_add_expiry(command, options) do
    case Keyword.get(options, :ex) do
      nil -> command
      ttl -> command ++ ["EX", to_string(ttl)]
    end
  end

  defp execute_command(command, conn) do
    Redix.command(conn, command)
  rescue
    e ->
      Logger.error("Failed to execute Valkey command: #{inspect(e)}")
      {:error, :valkey_error}
  end

  defp start_connection(config) do
    config
    |> build_connection_options()
    |> start_redix_connection()
  end

  defp build_connection_options(config) do
    host = Map.get(config, :host, "localhost")
    port = Map.get(config, :port, 6379)
    password = Map.get(config, :password)
    database = Map.get(config, :database, 0)

    [
      host: host,
      port: port,
      database: database,
      timeout: @valkey_timeout
    ]
    |> maybe_add_password(password)
    |> then(&{host, port, &1})
  end

  defp maybe_add_password(options, nil), do: options
  defp maybe_add_password(options, password), do: Keyword.put(options, :password, password)

  defp start_redix_connection({host, port, options}) do
    case Redix.start_link(options) do
      {:ok, _conn} = result ->
        Logger.info("Connected to Valkey at #{host}:#{port}")
        result

      {:error, reason} = error ->
        Logger.error("Failed to connect to Valkey: #{inspect(reason)}")
        error
    end
  end
end
