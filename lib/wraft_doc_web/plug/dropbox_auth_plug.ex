defmodule WraftDocWeb.DropboxAuthPlug do
  @moduledoc """
  Plug to get google token from AuthTokens
  """
  import Plug.Conn
  alias WraftDoc.Integrations

  def init(default), do: default

  def call(conn, _opts) do
    current_user = conn.assigns[:current_user]

    case Integrations.get_latest_token(current_user, :dropbox_oauth) do
      nil ->
        conn
        |> send_resp(401, Jason.encode!(%{error: "Not authenticated"}))
        |> halt()

      token ->
        assign(conn, :google_token, token)
    end
  end
end
