defmodule WraftDocWeb.Api.V1.HealthController do
  @moduledoc """
  Simple health check API that always responds with status `ok`.
  """
  use WraftDocWeb, :controller
  use PhoenixSwagger

  def swagger_definitions do
    %{
      HealthResponse:
        swagger_schema do
          title("HealthResponse")
          description("Health check response")

          properties do
            status(:string, "Service status", example: "ok")
          end

          example(%{
            status: "ok"
          })
        end
    }
  end

  swagger_path :check_health do
    get("/health")
    summary("Service Health Check")
    description("Returns a simple `ok` status if the service is up.")

    response(200, "Successful response", Schema.ref(:HealthResponse))
  end

  def check_health(conn, _), do: json(conn, %{status: "ok"})
end
