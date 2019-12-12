defmodule ExStarterWeb.PageController do
  use ExStarterWeb, :controller

  def index(conn, _params) do
    body = Poison.encode!(%{error: "Not Authenticated. Sign up first.!"})
    send_resp(conn, 401, body)
  end
end
