defmodule WraftDocWeb.PageController do
  use WraftDocWeb, :controller

  def index(conn, _params) do
    version = to_string(Application.spec(:wraft_doc, :vsn))
    render(conn, "index.html", version: version)
  end
end
