defmodule WraftDocWeb.Plugs.KaffyAdminPlug do
  @moduledoc """
  Adds schema params under resource.
  """
  @spec init(Keyword.t()) :: Keyword.t()
  def init(opts), do: opts

  @spec call(Plug.Conn.t(), Keyword.t()) :: Plug.Conn.t()
  def call(%Plug.Conn{params: params} = conn, _opts) when is_map(params) do
    if params["context"] == "enterprise" && params["resource"] == "enterprise_plan" do
      params
      |> Map.put("enterprise_plan", params["plan"])
      |> then(&%{conn | params: &1})
    else
      conn
    end
  end
end
