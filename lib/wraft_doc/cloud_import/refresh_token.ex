defmodule WraftDoc.CloudImport.RefreshToken do
  @moduledoc """
  Scheduled Refreshes tokens for all integrations.
  """
  use GenServer
  require Logger
  alias WraftDoc.CloudImport.CloudAuth

  @refresh_margin 300

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def run_refresh(provider, org_id, refresh_token) do
    GenServer.cast(__MODULE__, {:refresh, provider, org_id, refresh_token})
  end

  @impl true
  def init(state), do: {:ok, state}

  @impl true
  def handle_cast({:refresh, provider, org_id, refresh_token}, state) do
    safe(fn -> do_refresh(provider, org_id, refresh_token) end)
    {:noreply, state}
  end

  @impl true
  def handle_info({:refresh, provider, org_id, refresh_token}, state) do
    safe(fn -> do_refresh(provider, org_id, refresh_token) end)
    {:noreply, state}
  end

  defp safe(fun) do
    fun.()
  rescue
    exception ->
      Logger.error("RefreshToken crashed: #{Exception.format(:error, exception, __STACKTRACE__)}")

      reraise exception, __STACKTRACE__
  end

  defp do_refresh(:google_drive, org_id, %{"refresh_token" => refresh_token} = metadata) do
    case CloudAuth.refresh_token(:google_drive, org_id, refresh_token) do
      {:ok, _normalized_token} ->
        schedule_refresh(:google_drive, org_id, metadata)

      {:error, reason} ->
        Logger.error("Failed to refresh Google Drive token for #{org_id}: #{inspect(reason)}")
    end
  end

  defp schedule_refresh(
         provider,
         org_id,
         %{"access_token" => _at, "expires_at" => expires_at} = normalized_token
       ) do
    now = System.system_time(:second)
    delay = max(expires_at - now - @refresh_margin, 0)

    Process.send_after(self(), {:refresh, provider, org_id, normalized_token}, delay * 1000)
  end
end
