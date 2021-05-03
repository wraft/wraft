defmodule WraftDocWeb.PageController do
  use WraftDocWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
