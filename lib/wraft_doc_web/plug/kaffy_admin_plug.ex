defmodule WraftDocWeb.Plugs.KaffyAdminPlug do
  def init(opts), do: opts

  def call(conn, _opts) do
    if conn.params["context"] == "enterprise" && conn.params["resource"] == "enterprise_plan" do
      params = Map.put(conn.params, "enterprise_plan", conn.params["plan"])
      %{conn | params: params}
    else
      conn
    end
  end
end
