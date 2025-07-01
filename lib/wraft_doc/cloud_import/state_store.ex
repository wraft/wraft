defmodule WraftDoc.CloudImport.StateStore do
  @moduledoc """
  A GenServer-based state store using ETS for caching user-specific data.
  This store allows for storing key-value pairs for each user with a 10-minute expiration time.
  """
  use GenServer

  @table :cloud_state_store

  def start_link(_), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)

  def init(_) do
    :ets.new(@table, [:named_table, :public, :set])
    {:ok, nil}
  end

  def put(user_id, key, value), do: :ets.insert(@table, {{user_id, key}, {value, now()}})

  def get(user_id, key) do
    case :ets.lookup(@table, {user_id, key}) do
      [{{^user_id, ^key}, {value, inserted_at}}] ->
        if expired?(inserted_at), do: :error, else: {:ok, value}

      [] ->
        :error
    end
  end

  def delete(user_id, key), do: :ets.delete(@table, {user_id, key})

  defp now, do: System.system_time(:second)

  defp expired?(inserted_at), do: now() - inserted_at > 600
end
