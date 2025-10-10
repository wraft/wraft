defmodule WraftDoc.CloudImport.TokenRefreshServer do
  @moduledoc """
  GenServer for refreshing access tokens
  """

  use GenServer
  require Logger

  alias WraftDoc.CloudImport.CloudAuth

  @max_refresh_count 3
  # Refresh 5 minutes before token expires (safety margin)
  @refresh_margin_seconds 300

  # Client API

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

    state = %{
      organisation_id: organisation_id,
      refresh_token: refresh_token,
      last_refresh: nil,
      refresh_count: 0,
      expires_at: nil
    }

    send(self(), :refresh_token)

    {:ok, state}
  end

  @impl true
  def handle_info(:refresh_token, %{refresh_count: count} = state)
      when count >= @max_refresh_count do
    {:stop, :normal, state}
  end

  @impl true
  def handle_info(:refresh_token, state) do
    new_state =
      case refresh_google_token(state.organisation_id, state.refresh_token) do
        {:ok, normalized} ->
          expires_at = normalized["expires_at"]

          updated_state = %{
            state
            | last_refresh: DateTime.utc_now(),
              refresh_count: state.refresh_count + 1,
              expires_at: expires_at
          }

          # Schedule next refresh based on expiry time
          if updated_state.refresh_count < @max_refresh_count do
            schedule_refresh_based_on_expiry(expires_at)
          end

          updated_state

        {:error, _reason} ->
          if state.refresh_count < @max_refresh_count do
            Process.send_after(self(), :refresh_token, :timer.seconds(30))
          end

          state
      end

    {:noreply, new_state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  # Private Functions

  defp schedule_refresh_based_on_expiry(expires_at) do
    now = DateTime.to_unix(DateTime.utc_now())
    time_until_expiry = expires_at - now

    refresh_in_seconds = max(time_until_expiry - @refresh_margin_seconds, 10)

    Process.send_after(self(), :refresh_token, :timer.seconds(refresh_in_seconds))
  end

  defp refresh_google_token(organisation_id, refresh_token) do
    CloudAuth.refresh_token(:google_drive, organisation_id, refresh_token)
  end

  # Helper function to check current state (useful for debugging)
  def get_state do
    GenServer.call(__MODULE__, :get_state)
  end
end
