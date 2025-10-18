defmodule WraftDoc.CloudImport.Token.RefreshServer do
  @moduledoc """
  A GenServer that **automatically refreshes OAuth access tokens** before expiry.

  Each organisation runs its own supervised process that:
    • Stores and refreshes tokens using its `refresh_token`
    • Schedules the next refresh based on `expires_in`
    • Stops automatically after the refresh token expires (~7 days)

  ## Usage

  ```elixir
  # Start token refresh for organisations
  {:ok, _} = WraftDoc.CloudImport.Token.Manager.start("org1", "refresh_abc")
  {:ok, _} = WraftDoc.CloudImport.Token.Manager.start("org2", "refresh_def")

  # Get the current access token
  token1 = WraftDoc.CloudImport.Token.Manager.get_token("org1")
  token2 = WraftDoc.CloudImport.Token.Manager.get_token("org2")
  """

  use GenServer
  require Logger

  alias WraftDoc.CloudImport.CloudAuth
  alias WraftDoc.CloudImport.TokenStore

  # TODO Improve to store and manage multiple integrations tokens.

  @buffer_seconds 30
  @max_duration 7 * 24 * 60 * 60

  def start_link(opts) do
    name =
      opts
      |> Keyword.fetch!(:organisation_id)
      |> via_tuple()

    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def stop, do: GenServer.stop(__MODULE__)

  def get_state(org_id), do: GenServer.call(via_tuple(org_id), :get_state)

  @impl true
  def init(opts) do
    organisation_id = Keyword.fetch!(opts, :organisation_id)
    refresh_token = Keyword.fetch!(opts, :refresh_token)

    state =
      organisation_id
      |> TokenStore.get()
      |> case do
        nil ->
          %{
            organisation_id: organisation_id,
            access_token: nil,
            expires_at: nil,
            refresh_token: refresh_token,
            start_time: DateTime.utc_now(),
            refresh_count: 0
          }

        state ->
          state
      end

    interval = compute_interval(state)
    Process.send_after(self(), :refresh_token, interval * 1000)

    {:ok, state}
  end

  @impl true
  def handle_info(:refresh_token, state) do
    now = DateTime.utc_now()
    elapsed = DateTime.diff(now, state.start_time, :second)

    if elapsed >= @max_duration do
      Logger.info("TokenRefreshServer stopping: max duration reached")
      {:stop, :normal, state}
    else
      state.organisation_id
      |> refresh_google_token(state.refresh_token)
      |> case do
        {:ok,
         %{
           "access_token" => access_token,
           "expires_in" => expires_in
         }} ->
          expires_at = DateTime.add(now, expires_in, :second)

          new_state = %{
            state
            | access_token: access_token,
              expires_at: expires_at,
              refresh_count: state.refresh_count + 1
          }

          TokenStore.put(state.organisation_id, new_state)

          interval = max(expires_in - @buffer_seconds, 1)
          Process.send_after(self(), :refresh_token, interval * 1000)

          Logger.info(
            "Refreshed token for #{state.organisation_id}, next refresh in #{interval}s"
          )

          {:noreply, new_state}

        {:error, reason} ->
          Logger.error("Failed to refresh token for #{state.organisation_id}: #{inspect(reason)}")
          Process.send_after(self(), :refresh_token, 60_000)
          {:noreply, state}
      end
    end
  end

  @impl true
  def handle_call(:get_state, _from, state), do: {:reply, state, state}

  defp via_tuple(org_id), do: {:via, Registry, {WraftDoc.TokenRegistry, org_id}}

  defp refresh_google_token(organisation_id, refresh_token),
    do: CloudAuth.refresh_token(:google_drive, organisation_id, refresh_token)

  defp compute_interval(%{expires_at: nil}), do: 0

  defp compute_interval(%{expires_at: expires_at}) do
    interval = DateTime.diff(expires_at, DateTime.utc_now(), :second) - @buffer_seconds
    max(interval, 0)
  end
end
