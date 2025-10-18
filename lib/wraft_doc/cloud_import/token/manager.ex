defmodule WraftDoc.CloudImport.Token.Manager do
  @moduledoc """
  TokenServer manager
  """
  alias DynamicSupervisor
  alias WraftDoc.CloudImport.Token.RefreshServer

  @supervisor WraftDoc.TokenSupervisor

  # TODO: Centralize integration token management for multiple orgs,
  # multiple integrations, including refresh and error handling.

  @doc """
  Starts GenServer for token.
  """
  @spec start(Ecto.UUID.t(), String.t()) :: {:ok, pid()} | {:error, any()}
  def start(org_id, refresh_token) do
    spec = {RefreshServer, organisation_id: org_id, refresh_token: refresh_token}
    DynamicSupervisor.start_child(@supervisor, spec)
  end

  @doc """
  Retrieves access token from State.
  """
  @spec get_token(Ecto.UUID.t()) :: nil | String.t()
  def get_token(org_id) do
    case RefreshServer.get_state(org_id) do
      %{access_token: token} -> token
      _ -> nil
    end
  end
end
