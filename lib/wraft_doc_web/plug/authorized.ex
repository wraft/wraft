defmodule WraftDocWeb.Plug.Authorized do
  @moduledoc false
  # TODO WD-364 *Refactor the existing access control plug to follow the new implementation

  def init(_params) do
  end

  def call(conn, _params) do
    conn
  end
end
