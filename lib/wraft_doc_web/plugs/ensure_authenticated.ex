defmodule WraftDocWeb.Plug.EnsureAuthenticated do
  @moduledoc """
  Ensures that a request is authenticated via either API Key or JWT.

  This plug checks if current_user is set in conn.assigns.
  If not, it returns a 401 Unauthorized response.

  This works with both API Key and JWT authentication methods.
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      send_unauthorized_response(conn)
    end
  end

  defp send_unauthorized_response(conn) do
    body = Jason.encode!(%{errors: "Unauthorized. Please provide valid authentication."})

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(401, body)
    |> halt()
  end
end
