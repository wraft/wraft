defmodule WraftDocWeb.PageController do
  use WraftDocWeb, :controller

  def index(conn, _params) do
    version = Application.spec(:wraft_doc, :vsn) |> to_string()
    render(conn, "index.html", version: version)
  end
end
