defmodule WraftDocWeb.Api.V1.HealthController do
  @moduledoc """
  Simple health check API that always responds with status `ok`.
  """
  use WraftDocWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias WraftDocWeb.Schemas.Health, as: HealthSchema

  tags(["Health"])

  operation(:check_health,
    summary: "Service Health Check",
    description: "Returns a simple `ok` status if the service is up.",
    responses: [
      ok: {"Successful response", "application/json", HealthSchema.HealthResponse}
    ]
  )

  def check_health(conn, _), do: json(conn, %{status: "ok"})
end
