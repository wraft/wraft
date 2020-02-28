defmodule WraftDocWeb.Api.V1.LayoutController do
  use WraftDocWeb, :controller
  use PhoenixSwagger

  action_fallback(WraftDocWeb.FallbackController)
  alias WraftDoc.{Document, Document.Layout}

  def swagger_definitions do
    %{
      LayoutRequest:
        swagger_schema do
          title("Layout Request")
          description("Create layout request.")

          properties do
            name(:string, "Layout's name", required: true)
            description(:string, "Layout's description")
            width(:float, "Width of the layout")
            height(:float, "Height of the layout")
            unit(:string, "Unit of dimensions")
            slug(:string, "Name of the slug to be used for the layout")
            engine_id(:integer, "ID of the engine selected")
          end

          example(%{
            name: "Official Letter",
            description: "An official letter",
            width: 40.0,
            height: 20.0,
            unit: "cm",
            slug: "Pandoc",
            engine_id: "1232148nb3478"
          })
        end,
      Layout:
        swagger_schema do
          title("Layout")
          description("A Layout")

          properties do
            id(:string, "The ID of the layout", required: true)
            name(:string, "Layout's name", required: true)
            description(:string, "Layout's description")
            width(:float, "Width of the layout")
            height(:float, "Height of the layout")
            unit(:string, "Unit of dimensions")
            slug(:string, "Name of the slug to be used for the layout")
            inserted_at(:string, "When was the layout created", format: "ISO-8601")
            updated_at(:string, "When was the layout last updated", format: "ISO-8601")
          end

          example(%{
            id: "1232148nb3478",
            name: "Official Letter",
            description: "An official letter",
            width: 40.0,
            height: 20.0,
            unit: "cm",
            slug: "Pandoc",
            updated_at: "2020-01-21T14:00:00Z",
            inserted_at: "2020-02-21T14:00:00Z"
          })
        end,
      LayoutAndEngine:
        swagger_schema do
          title("Layout and Engine")
          description("Layout to be used for the generation of a document.")

          properties do
            id(:string, "The ID of the layout", required: true)
            name(:string, "Layout's name", required: true)
            description(:string, "Layout's description")
            width(:float, "Width of the layout")
            height(:float, "Height of the layout")
            unit(:string, "Unit of dimensions")
            slug(:string, "Name of the slug to be used for the layout")
            engine(Schema.ref(:Engine))
            inserted_at(:string, "When was the layout created", format: "ISO-8601")
            updated_at(:string, "When was the layout last updated", format: "ISO-8601")
          end

          example(%{
            id: "1232148nb3478",
            name: "Official Letter",
            description: "An official letter",
            width: 40.0,
            height: 20.0,
            unit: "cm",
            slug: "Pandoc",
            engine: %{
              id: "1232148nb3478",
              name: "Pandoc",
              api_route: "",
              updated_at: "2020-01-21T14:00:00Z",
              inserted_at: "2020-02-21T14:00:00Z"
            },
            updated_at: "2020-01-21T14:00:00Z",
            inserted_at: "2020-02-21T14:00:00Z"
          })
        end,
      LayoutsAndEngines:
        swagger_schema do
          title("Layouts and its Engines")
          description("All layouts that have been created and their engines")
          type(:array)
          items(Schema.ref(:LayoutAndEngine))
        end,
      ShowLayout:
        swagger_schema do
          title("Layout and all its details")
          description("API to show a layout and all its details")

          properties do
            layout(Schema.ref(:LayoutAndEngine))
            creator(Schema.ref(:User))
          end

          example(%{
            layout: %{
              id: "1232148nb3478",
              name: "Official Letter",
              description: "An official letter",
              width: 40.0,
              height: 20.0,
              unit: "cm",
              slug: "Pandoc",
              engine: %{
                id: "1232148nb3478",
                name: "Pandoc",
                api_route: "",
                updated_at: "2020-01-21T14:00:00Z",
                inserted_at: "2020-02-21T14:00:00Z"
              },
              updated_at: "2020-01-21T14:00:00Z",
              inserted_at: "2020-02-21T14:00:00Z"
            },
            creator: %{
              id: "1232148nb3478",
              name: "John Doe",
              email: "email@xyz.com",
              email_verify: true,
              updated_at: "2020-01-21T14:00:00Z",
              inserted_at: "2020-02-21T14:00:00Z"
            }
          })
        end
    }
  end

  @doc """
  Create a layout.
  """
  swagger_path :create do
    post("/layouts")
    summary("Create layout")
    description("Create layout API")

    parameters do
      layout(:body, Schema.ref(:LayoutRequest), "Layout to be created", required: true)
    end

    response(200, "Ok", Schema.ref(:LayoutAndEngine))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec create(Plug.Conn.t(), map) :: Plug.Conn.t()
  def create(conn, params) do
    current_user = conn.assigns[:current_user]

    with %Layout{} = layout <- Document.create_layout(current_user, params) do
      conn
      |> render("create.json", doc_layout: layout)
    end
  end

  @doc """
  Layout index.
  """
  swagger_path :index do
    get("/layouts")
    summary("Layout index")
    description("API to get the list of all layouts created so far")

    response(200, "Ok", Schema.ref(:LayoutsAndEngines))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec index(Plug.Conn.t(), map) :: Plug.Conn.t()
  def index(conn, _params) do
    layouts = Document.layout_index()

    conn
    |> render("index.json", doc_layouts: layouts)
  end

  @doc """
  Show a Layout.
  """
  swagger_path :show do
    get("/layouts/{id}")
    summary("Show a Layout")
    description("API to show details of a layout")

    parameters do
      id(:path, :string, "layout id", required: true)
    end

    response(200, "Ok", Schema.ref(:ShowLayout))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec show(Plug.Conn.t(), map) :: Plug.Conn.t()
  def show(conn, %{"id" => uuid}) do
    with %Layout{} = layout <- Document.show_layout(uuid) do
      conn
      |> render("show.json", doc_layout: layout)
    end
  end

  @doc """
  Update a Layout.
  """
  swagger_path :update do
    put("/layouts/{id}")
    summary("Update a Layout")
    description("API to update a layout")

    parameters do
      id(:path, :string, "layout id", required: true)
      layout(:body, Schema.ref(:LayoutRequest), "Layout to be updated", required: true)
    end

    response(200, "Ok", Schema.ref(:ShowLayout))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec update(Plug.Conn.t(), map) :: Plug.Conn.t()
  def update(conn, %{"id" => uuid} = params) do
    with %Layout{} = layout <- Document.get_layout(uuid),
         %Layout{} = layout <- Document.update_layout(layout, params) do
      conn
      |> render("show.json", doc_layout: layout)
    end
  end

  @doc """
  Delete a Layout.
  """
  swagger_path :delete do
    PhoenixSwagger.Path.delete("/layouts/{id}")
    summary("Delete a Layout")
    description("API to delete a layout")

    parameters do
      id(:path, :string, "layout id", required: true)
    end

    response(200, "Ok", Schema.ref(:Layout))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec delete(Plug.Conn.t(), map) :: Plug.Conn.t()
  def delete(conn, %{"id" => uuid}) do
    with %Layout{} = layout <- Document.get_layout(uuid),
         {:ok, %Layout{}} <- Document.delete_layout(layout) do
      conn
      |> render("layout.json", doc_layout: layout)
    end
  end
end
