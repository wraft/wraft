defmodule WraftDocWeb.Guardian.AuthErrorHandler do
  @moduledoc """
  Error handler for Guradian.
  """
  import Plug.Conn

  def auth_error(conn, {type, _reason}, _opts) do
    body = Jason.encode!(%{message: to_string(type)})
    send_resp(conn, 401, body)
  end

  def auth_error(conn, {:error, :no_user}) do
    body = Jason.encode!(%{errors: "No user found"})

    conn |> send_resp(404, body) |> halt()
  end

  def auth_error(conn, {:error, :no_org}) do
    body = Jason.encode!(%{errors: "No organisation found"})

    conn |> send_resp(404, body) |> halt()
  end
end
