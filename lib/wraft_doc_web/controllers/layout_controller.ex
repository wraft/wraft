defmodule WraftDocWeb.Api.V1.LayoutController do
  use WraftDocWeb, :controller
  import Ecto.Query, warn: false
  action_fallback(WraftDocWeb.FallbackController)

  @spec create(Plug.Conn.t(), map) :: Plug.Conn.t()
  def create(conn, params) do
  end
end
