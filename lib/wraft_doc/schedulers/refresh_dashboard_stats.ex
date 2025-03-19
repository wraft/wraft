defmodule WraftDoc.Schedulers.RefreshDashboardStats do
  @moduledoc """
  Refreshes the dashboard stats
  """
  use GenServer

  # Refresh every hour
  @refresh_interval :timer.minutes(30)

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{})
  end

  def init(state) do
    schedule_refresh()
    {:ok, state}
  end

  def handle_info(:refresh, state) do
    refresh_materialized_view()
    schedule_refresh()
    {:noreply, state}
  end

  defp schedule_refresh do
    Process.send_after(self(), :refresh, @refresh_interval)
  end

  defp refresh_materialized_view do
    WraftDoc.Repo.query!("REFRESH MATERIALIZED VIEW dashboard_stats")
  end
end
