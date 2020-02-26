defmodule WraftDocWeb.Api.V1.LayoutController do
  use WraftDocWeb, :controller

  action_fallback(WraftDocWeb.FallbackController)
  alias WraftDoc.{Document, Document.Layout}

  @spec create(Plug.Conn.t(), map) :: Plug.Conn.t()
  def create(conn, params) do
    current_user = conn.assigns[:current_user]

    with %Layout{} = layout <- Document.create_layout(current_user, params) do
      conn
      |> render("create.json", doc_layout: layout)
    end
  end
end
