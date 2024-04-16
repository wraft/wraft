defmodule WraftDoc.Repo.Migrations.FixStateOrderDuplicity do
  @moduledoc """
  Script for rectifying the order duplicity in state table

   mix run priv/repo/data/migrations/fix_order_state_duplicity.exs
  """
  require Logger
  import Ecto.Query
  alias WraftDoc.Enterprise.Flow.State
  alias WraftDoc.Repo

  Logger.info("Starting order update for State records")

  State
  |> where([s], not is_nil(s.flow_id))
  |> Repo.all()
  |> Enum.group_by(& &1.flow_id)
  |> Enum.map(fn {flow_id, states} ->
    Logger.info("Updating order for flow_id: #{flow_id}")

    states
    |> Enum.with_index(1)
    |> Enum.map(fn {state, order} ->
      Logger.info("Updating order to #{order} for State: #{inspect(state)}")

      state
      |> Ecto.Changeset.change(%{order: order})
      |> Repo.update!()
    end)
  end)

  Logger.info("Order update completed")
end
