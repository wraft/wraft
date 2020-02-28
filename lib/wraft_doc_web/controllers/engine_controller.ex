defmodule WraftDocWeb.Api.V1.EngineController do
  use WraftDocWeb, :controller
  use PhoenixSwagger

  action_fallback(WraftDocWeb.FallbackController)
  alias WraftDoc.{Document}

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

    response(200, "Ok", Schema.ref(:Engines))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec index(Plug.Conn.t(), map) :: Plug.Conn.t()
  def index(conn, _params) do
    engines = Document.engines_list()

    conn
    |> render("index.json", engines: engines)
  end
end
