defmodule ExStarterWeb.Guardian.AuthErrorHandler do
  @moduledoc """
  Error handler for Guradian.
  """
  import Plug.Conn

  def auth_error(conn, {type, _reason}, _opts) do
    body = Poison.encode!(%{message: to_string(type)})
    send_resp(conn, 401, body)
  end
end
