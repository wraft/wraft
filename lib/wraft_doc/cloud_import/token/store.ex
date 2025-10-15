defmodule WraftDoc.CloudImport.TokenStore do
  @moduledoc """
  Simple ETS-based storage for access tokens and expiry per organisation.
  """
  use GenServer

  @table :cloud_token_store

  def start_link(_args), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  @impl true
  def init(state) do
    :ets.new(@table, [:named_table, :public, :set, {:read_concurrency, true}])
    {:ok, state}
  end

  def put(org_id, state), do: :ets.insert(@table, {org_id, state})

  def get(org_id) do
    case :ets.lookup(@table, org_id) do
      [{^org_id, state}] -> state
      [] -> nil
    end
  end

  def delete(org_id), do: :ets.delete(@table, org_id)
end
