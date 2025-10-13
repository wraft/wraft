defmodule WraftDocWeb.GoogleAuthPlug do
  @moduledoc """
  Plug to get google token from AuthTokens
  """
  import Plug.Conn
  alias WraftDoc.Integrations

  def init(default), do: default

  def call(conn, _opts) do
    conn.assigns[:current_user]
    |> Integrations.get_latest_token("google_drive")
    |> case do
      {:ok, token} ->
        assign(conn, :google_token, token)

      _ ->
        conn
        |> send_resp(403, Jason.encode!(%{error: "Not authenticated"}))
        |> halt()
    end
  end
end
