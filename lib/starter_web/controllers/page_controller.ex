defmodule StarterWeb.PageController do
  use StarterWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
