defmodule WraftDocWeb.DropboxTokenPlug do
  @moduledoc """
  Plug to get google token from AuthTokens
  """
  import Plug.Conn
  alias WraftDoc.AuthTokens

  def init(default), do: default

  def call(conn, _opts) do
    case AuthTokens.get_latest_token(:dropbox_oauth) do
      nil ->
        conn
        |> send_resp(401, Jason.encode!(%{error: "Not authenticated"}))
        |> halt()

      token ->
        assign(conn, :google_token, token)
    end
  end
end
