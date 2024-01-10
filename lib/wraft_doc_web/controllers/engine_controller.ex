defmodule WraftDocWeb.Api.V1.EngineController do
  use WraftDocWeb, :controller
  use PhoenixSwagger

  plug WraftDocWeb.Plug.AddActionLog

  plug WraftDocWeb.Plug.Authorized, index: "engine:show"

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.Document

  def swagger_definitions do
    %{
      Engine:
        swagger_schema do
          title("Render engine")
          description("A render engine to be used for document generation")

          properties do
            id(:string, "The ID of the engine", required: true)
            name(:string, "Engine's name", required: true)
            api_route(:string, "API route to be used")
            inserted_at(:string, "When was the engine inserted", format: "ISO-8601")
            updated_at(:string, "When was the engine last updated", format: "ISO-8601")
          end

          example(%{
            id: "1232148nb3478",
            name: "Pandoc",
            api_route: "",
            updated_at: "2020-01-21T14:00:00Z",
            inserted_at: "2020-02-21T14:00:00Z"
          })
        end,
      Engines:
        swagger_schema do
          title("Engines")
          description("All engines that have been created")
          type(:array)
          items(Schema.ref(:Engine))
        end,
      EngineIndex:
        swagger_schema do
          properties do
            engines(Schema.ref(:Engines))
            page_number(:integer, "Page number")
            total_pages(:integer, "Total number of pages")
            total_entries(:integer, "Total number of contents")
          end

          example(%{
            engines: [
              %{
                id: "1232148nb3478",
                name: "Pandoc",
                api_route: "",
                updated_at: "2020-01-21T14:00:00Z",
                inserted_at: "2020-02-21T14:00:00Z"
              }
            ],
            page_number: 1,
            total_pages: 2,
            total_entries: 15
          })
        end
    }
  end

  @doc """
  Engine index.
  """
  swagger_path :index do
    get("/engines")
    summary("List of all enignes")
    description("API to list of all enignes creates/seeded so far")

    parameter(:page, :query, :string, "Page number")

    response(200, "Ok", Schema.ref(:EngineIndex))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec index(Plug.Conn.t(), map) :: Plug.Conn.t()
  def index(conn, params) do
    with %{
           entries: engines,
           page_number: page_number,
           total_pages: total_pages,
           total_entries: total_entries
         } <- Document.engines_list(params) do
      render(conn, "index.json",
        engines: engines,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      )
    end
  end
end
