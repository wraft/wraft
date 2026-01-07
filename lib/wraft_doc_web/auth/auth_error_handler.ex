defmodule WraftDocWeb.Guardian.AuthErrorHandler do
  @moduledoc """
  Error handler for Guardian.
  """
  import Plug.Conn

  def auth_error(conn, {:invalid_token, _reason}, _opts) do
    body = Jason.encode!(%{errors: "Token is either expired or invalid. Login again."})
    conn |> put_resp_content_type("application/json") |> send_resp(401, body) |> halt()
  end

  def auth_error(conn, {:unauthenticated, _reason}, _opts) do
    body = Jason.encode!(%{errors: "Unauthorized. Please provide valid authentication."})
    conn |> put_resp_content_type("application/json") |> send_resp(401, body) |> halt()
  end

  def auth_error(conn, {type, _reason}, _opts) do
    body = Jason.encode!(%{errors: to_string(type)})
    conn |> put_resp_content_type("application/json") |> send_resp(401, body) |> halt()
  end

  def auth_error(conn, {:error, :no_user}) do
    body = Jason.encode!(%{errors: "No user found"})

    conn |> put_resp_content_type("application/json") |> send_resp(404, body) |> halt()
  end

  def auth_error(conn, {:error, :no_org}) do
    body = Jason.encode!(%{errors: "No organisation found"})

    conn |> put_resp_content_type("application/json") |> send_resp(404, body) |> halt()
  end
end
