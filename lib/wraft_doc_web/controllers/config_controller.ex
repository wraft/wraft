defmodule WraftDocWeb.Api.V1.ConfigController do
  @moduledoc """
  Public runtime configuration for the frontend.
  """
  use WraftDocWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias WraftDoc.Enterprise
  alias WraftDocWeb.Schemas.Config, as: ConfigSchema

  tags(["Config"])

  operation(:show,
    summary: "Public runtime configuration",
    description: "Returns deployment-mode flags the frontend needs before login.",
    responses: [
      ok: {"Ok", "application/json", ConfigSchema.ConfigResponse}
    ]
  )

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, _params) do
    json(conn, %{self_hosted: Enterprise.self_hosted?()})
  end
end
