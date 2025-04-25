defmodule WraftDoc.SessionCache do
  @moduledoc """
  A GenServer-based session cache with TTL support and automatic expiration cleanup.

  The cache uses ETS for concurrent read access while serializing write operations
  through the GenServer process to prevent race conditions.
  """

  use GenServer

  @table_name :session_cache
  # 1 minute in milliseconds
  @default_cleanup_interval 60_000
  # Minimum TTL of 5 seconds
  @min_ttl 5_000

  @type key :: any()
  @type value :: any()
  @type ttl :: :infinity | pos_integer()

  # Client API

  @doc """
  Starts the session cache GenServer.
  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Retrieves a value from the cache if it exists and is not expired.
  """
  @spec get(key) :: {:ok, value} | {:error, :not_found}
  def get(key) do
    case :ets.lookup(@table_name, key) do
      [{^key, value, expires_at}] ->
        now = System.system_time(:millisecond)

        if expires_at == :infinity or expires_at > now do
          {:ok, value}
        else
          GenServer.cast(__MODULE__, {:delete, key})
          {:error, :not_found}
        end

      [] ->
        {:error, :not_found}
    end
  end

  @doc """
  Stores a value in the cache with an optional TTL (in milliseconds).

  Minimum TTL is #{@min_ttl} milliseconds. Values below this will be clamped.
  """
  @spec put(key, value, ttl) :: :ok
  def put(key, value, ttl \\ :infinity) do
    GenServer.call(__MODULE__, {:put, key, value, ttl})
  end

  @doc """
  Removes a specific entry from the cache.
  """
  @spec delete(key) :: :ok
  def delete(key) do
    GenServer.cast(__MODULE__, {:delete, key})
  end

  @doc """
  Removes all entries matching a pattern.
  """
  @spec delete_pattern(:ets.match_pattern()) :: :ok
  def delete_pattern(pattern) do
    GenServer.cast(__MODULE__, {:delete_pattern, pattern})
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    cleanup_interval = opts[:cleanup_interval] || @default_cleanup_interval

    state = %{
      cleanup_interval: cleanup_interval,
      table:
        :ets.new(@table_name, [
          :set,
          :named_table,
          :protected,
          {:read_concurrency, true},
          {:write_concurrency, false}
        ])
    }

    schedule_cleanup(state.cleanup_interval)
    {:ok, state}
  end

  @impl true
  def handle_call({:put, key, value, ttl}, _from, state) do
    expires_at = calculate_expires_at(ttl)
    :ets.insert(state.table, {key, value, expires_at})
    {:reply, :ok, state}
  end

  @impl true
  def handle_cast({:delete, key}, state) do
    :ets.delete(state.table, key)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:delete_pattern, pattern}, state) do
    :ets.select_delete(state.table, [{{pattern, :_, :_}, [], [true]}])
    {:noreply, state}
  end

  @impl true
  def handle_info(:cleanup, state) do
    now = System.system_time(:millisecond)

    :ets.select_delete(state.table, [
      {{:"$1", :"$2", :"$3"},
       [
         {:andalso, {:"=/=", :"$3", :infinity}, {:<, :"$3", now}}
       ], [true]}
    ])

    schedule_cleanup(state.cleanup_interval)
    {:noreply, state}
  end

  defp calculate_expires_at(:infinity), do: :infinity

  defp calculate_expires_at(ttl) when is_integer(ttl) and ttl > 0 do
    System.system_time(:millisecond) + max(ttl, @min_ttl)
  end

  defp schedule_cleanup(interval) do
    Process.send_after(self(), :cleanup, interval)
  end
end
