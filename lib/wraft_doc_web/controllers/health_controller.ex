defmodule WraftDocWeb.Api.V1.HealthController do
  @moduledoc """
  Controller module for Instance approval
  """
  use WraftDocWeb, :controller
  use PhoenixSwagger

  def check_health(conn, _) do
    json(conn, %{status: "ok"})
  end
end
