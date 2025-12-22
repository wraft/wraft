defmodule WraftDocWeb.Api.V1.EngineController do
  use WraftDocWeb, :controller
  use OpenApiSpex.ControllerSpecs

  plug WraftDocWeb.Plug.AddActionLog

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.Documents
  alias WraftDocWeb.Schemas.Engine, as: EngineSchema
  alias WraftDocWeb.Schemas.Error

  tags(["Engines"])

  operation(:index,
    summary: "List of all enignes",
    description: "API to list of all enignes creates/seeded so far",
    parameters: [
      page: [in: :query, type: :string, description: "Page number"]
    ],
    responses: [
      ok: {"Ok", "application/json", EngineSchema.EngineIndex},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  @spec index(Plug.Conn.t(), map) :: Plug.Conn.t()
  def index(conn, params) do
    with %{
           entries: engines,
           page_number: page_number,
           total_pages: total_pages,
           total_entries: total_entries
         } <- Documents.engines_list(params) do
      render(conn, "index.json",
        engines: engines,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      )
    end
  end
end
