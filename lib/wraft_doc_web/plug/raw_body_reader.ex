defmodule WraftDocWeb.RawBodyReader do
  @moduledoc """
  Reads the raw body of a Plug.Conn and puts it into the conn.private
  """
  def read_body(conn, opts) do
    {:ok, body, conn} = Plug.Conn.read_body(conn, opts)
    conn = Plug.Conn.put_private(conn, :raw_body, body)
    {:ok, body, conn}
  end
end
