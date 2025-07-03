defmodule WraftDoc.SessionCache do
  @moduledoc """
  A GenServer-based session cache with TTL support and automatic expiration cleanup.

  The cache uses ETS for concurrent read access while serializing write operations
  through the GenServer process to prevent race conditions.
  """

  use GenServer
  require Logger

  @table_name :session_cache
  # 1 minute in milliseconds
  @default_cleanup_interval 60_000
  # Minimum TTL of 5 seconds
  @min_ttl 5_000
  # Maximum cache size to prevent DoS
  @max_cache_size 10_000

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
          :telemetry.execute([:session_cache, :hit], %{}, %{key: inspect(key)})
          {:ok, value}
        else
          :telemetry.execute([:session_cache, :miss], %{}, %{key: inspect(key), reason: :expired})
          GenServer.cast(__MODULE__, {:delete, key})
          {:error, :not_found}
        end

      [] ->
        :telemetry.execute([:session_cache, :miss], %{}, %{key: inspect(key), reason: :not_found})
        {:error, :not_found}
    end
  end

  @doc """
  Stores a value in the cache with an optional TTL (in milliseconds).

  Minimum TTL is #{@min_ttl} milliseconds. Values below this will be clamped.
  Returns {:error, :cache_full} if the cache has reached its maximum size.
  """
  @spec put(key, value, ttl) :: :ok | {:error, :cache_full}
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

  @doc """
  Gets cache statistics.
  """
  @spec stats() :: map()
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  @doc """
  Flushes all cache entries. Used primarily for testing.
  """
  @spec flush_all() :: :ok
  def flush_all do
    GenServer.call(__MODULE__, :flush_all)
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
    cache_size = :ets.info(state.table, :size)

    if cache_size >= @max_cache_size do
      Logger.warning("SessionCache: Cache full, rejecting new entry: #{inspect(key)}")
      :telemetry.execute([:session_cache, :put, :rejected], %{}, %{reason: :cache_full})
      {:reply, {:error, :cache_full}, state}
    else
      expires_at = calculate_expires_at(ttl)
      :ets.insert(state.table, {key, value, expires_at})
      :telemetry.execute([:session_cache, :put, :success], %{}, %{key: inspect(key)})
      {:reply, :ok, state}
    end
  end

  @impl true
  def handle_call(:stats, _from, state) do
    size = :ets.info(state.table, :size)
    memory = :ets.info(state.table, :memory)

    stats = %{
      size: size,
      memory_words: memory,
      max_size: @max_cache_size,
      table_info: :ets.info(state.table)
    }

    {:reply, stats, state}
  end

  @impl true
  def handle_call(:flush_all, _from, state) do
    :ets.delete_all_objects(state.table)
    Logger.info("SessionCache: All entries flushed")
    {:reply, :ok, state}
  end

  @impl true
  def handle_cast({:delete, key}, state) do
    :ets.delete(state.table, key)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:delete_pattern, pattern}, state) do
    deleted_count = :ets.select_delete(state.table, [{{pattern, :_, :_}, [], [true]}])
    Logger.debug("SessionCache: Deleted #{deleted_count} entries matching pattern")
    {:noreply, state}
  end

  @impl true
  def handle_info(:cleanup, state) do
    now = System.system_time(:millisecond)

    deleted_count =
      :ets.select_delete(state.table, [
        {{:"$1", :"$2", :"$3"},
         [
           {:andalso, {:"=/=", :"$3", :infinity}, {:<, :"$3", now}}
         ], [true]}
      ])

    if deleted_count > 0 do
      Logger.debug("SessionCache: Cleaned up #{deleted_count} expired entries")
    end

    :telemetry.execute([:session_cache, :cleanup], %{deleted_count: deleted_count})
    schedule_cleanup(state.cleanup_interval)
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, state) do
    Logger.info("SessionCache: Gracefully shutting down")
    :ets.delete(state.table)
    :ok
  end

  defp calculate_expires_at(:infinity), do: :infinity

  defp calculate_expires_at(ttl) when is_integer(ttl) and ttl > 0 do
    System.system_time(:millisecond) + max(ttl, @min_ttl)
  end

  defp schedule_cleanup(interval) do
    :telemetry.execute([:session_cache, :cleanup, :scheduled], %{interval: interval})
    Process.send_after(self(), :cleanup, interval)
  end
end
