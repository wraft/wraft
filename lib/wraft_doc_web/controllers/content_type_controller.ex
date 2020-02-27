defmodule WraftDocWeb.Api.V1.ContentTypeController do
  use WraftDocWeb, :controller

  action_fallback(WraftDocWeb.FallbackController)
  alias WraftDoc.{Document, Document.ContentType}

  @doc """
  Create a content type.
  """
  @spec create(Plug.Conn.t(), map) :: Plug.Conn.t()
  def create(conn, params) do
    current_user = conn.assigns[:current_user]

    with %ContentType{} = content_type <- Document.create_content_type(current_user, params) do
      conn
      |> render(:create, content_type: content_type)
    end
  end
end
