defmodule WraftDoc.CloudImport.TokenRefreshServer do
  @moduledoc """
  GenServer for refreshing access tokens at a fixed interval
  and stopping automatically after 7 days [as refresh token expires].
  """

  use GenServer
  require Logger

  alias WraftDoc.CloudImport.CloudAuth

  @refresh_interval_seconds 3_500

  @run_duration_seconds 7 * 24 * 60 * 60

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def stop do
    GenServer.stop(__MODULE__)
  end

  @impl true
  def init(opts) do
    organisation_id = Keyword.fetch!(opts, :organisation_id)
    refresh_token = Keyword.fetch!(opts, :refresh_token)

    now = DateTime.utc_now()

    state = %{
      organisation_id: organisation_id,
      refresh_token: refresh_token,
      start_time: now,
      last_refresh: nil,
      refresh_count: 0
    }

    send(self(), :refresh_token)
    {:ok, state}
  end

  @impl true
  def handle_info(:refresh_token, state) do
    now = DateTime.utc_now()
    elapsed = DateTime.diff(now, state.start_time, :second)

    if elapsed >= @run_duration_seconds do
      {:stop, :normal, state}
    else
      new_state =
        case refresh_google_token(state.organisation_id, state.refresh_token) do
          {:ok, _normalized} ->
            %{
              state
              | last_refresh: now,
                refresh_count: state.refresh_count + 1
            }

          {:error, _reason} ->
            state
        end

      Process.send_after(self(), :refresh_token, :timer.seconds(@refresh_interval_seconds))
      {:noreply, new_state}
    end
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  defp refresh_google_token(organisation_id, refresh_token) do
    CloudAuth.refresh_token(:google_drive, organisation_id, refresh_token)
  end

  def get_state do
    GenServer.call(__MODULE__, :get_state)
  end
end
