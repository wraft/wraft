defmodule WraftDocWeb.RawBodyReader do
  @moduledoc """
  Reads the raw body of a Plug.Conn and puts it into the conn.private
  """

  @spec read_body(Plug.Conn.t(), Keyword.t()) :: {:ok, binary(), Plug.Conn.t()}
  def read_body(conn, opts) do
    with {:ok, body, conn} <- Plug.Conn.read_body(conn, opts) do
      conn = Plug.Conn.put_private(conn, :raw_body, body)
      {:ok, body, conn}
    end
  end
end
