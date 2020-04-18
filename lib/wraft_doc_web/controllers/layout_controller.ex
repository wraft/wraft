defmodule WraftDocWeb.Api.V1.LayoutController do
  use WraftDocWeb, :controller
  use PhoenixSwagger
  plug(WraftDocWeb.Plug.Authorized)
  action_fallback(WraftDocWeb.FallbackController)
  alias WraftDoc.{Document, Document.Layout, Document.LayoutAsset, Document.Engine}

  def swagger_definitions do
    %{
      # LayoutRequest:
      #   swagger_schema do
      #     title("Layout Request")
      #     description("Create layout request.")

      #     properties do
      #       name(:string, "Layout's name", required: true)
      #       description(:string, "Layout's description")
      #       width(:float, "Width of the layout")
      #       height(:float, "Height of the layout")
      #       unit(:string, "Unit of dimensions")
      #       slug(:string, "Name of the slug to be used for the layout")
      #       engine_uuid(:string, "ID of the engine selected")
      #     end

      #     example(%{
      #       name: "Official Letter",
      #       description: "An official letter",
      #       width: 40.0,
      #       height: 20.0,
      #       unit: "cm",
      #       slug: "Pandoc",
      #       engine_uuid: "1232148nb3478"
      #     })
      #   end,
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
            slug_file(:string, "URL of the uploaded slug file")
            screenshot(:string, "URL of the uploaded screenshot")
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
            slug_file: "/official_letter.zip",
            screenshot: "/official_letter.jpg",
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
            slug_file(:string, "URL of the uploaded slug file")
            screenshot(:string, "URL of the uploaded screenshot")
            engine(Schema.ref(:Engine))
            assets(Schema.ref(:Assets))
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
            slug_file: "/official_letter.zip",
            screenshot: "/official_letter.jpg",
            engine: %{
              id: "1232148nb3478",
              name: "Pandoc",
              api_route: "",
              updated_at: "2020-01-21T14:00:00Z",
              inserted_at: "2020-02-21T14:00:00Z"
            },
            assets: [
              %{
                id: "1232148nb3478",
                name: "Asset",
                file: "/signature.pdf",
                updated_at: "2020-01-21T14:00:00Z",
                inserted_at: "2020-02-21T14:00:00Z"
              }
            ],
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
              slug_file: "/official_letter.zip",
              screenshot: "/official_letter.jpg",
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
        end,
      LayoutIndex:
        swagger_schema do
          properties do
            layouts(Schema.ref(:LayoutsAndEngines))
            page_number(:integer, "Page number")
            total_pages(:integer, "Total number of pages")
            total_entries(:integer, "Total number of contents")
          end

          example(%{
            layouts: [
              %{
                id: "1232148nb3478",
                name: "Official Letter",
                description: "An official letter",
                width: 40.0,
                height: 20.0,
                unit: "cm",
                slug: "Pandoc",
                slug_file: "/official_letter.zip",
                screenshot: "/official_letter.jpg",
                engine: %{
                  id: "1232148nb3478",
                  name: "Pandoc",
                  api_route: "",
                  updated_at: "2020-01-21T14:00:00Z",
                  inserted_at: "2020-02-21T14:00:00Z"
                },
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
  Create a layout.
  """
  swagger_path :create do
    post("/layouts")
    summary("Create layout")
    description("Create layout API")

    # parameters do
    #   layout(:body, Schema.ref(:LayoutRequest), "Layout to be created", required: true)
    # end

    consumes("multipart/form-data")

    parameter(:name, :formData, :string, "Layout's name", required: true)

    parameter(:description, :formData, :string, "Layout description", required: true)

    parameter(:width, :formData, :string, "Layout width", required: true)

    parameter(:height, :formData, :string, "Layout height", required: true)

    parameter(:unit, :formData, :string, "Layout dimension unit", required: true)

    parameter(:slug, :formData, :string, "Name of slug to be used")

    parameter(:slug_file, :formData, :file, "Slug file to upload")

    parameter(:screenshot, :formData, :file, "Screenshot to upload", required: true)

    parameter(:assets, :formData, :list, "IDs of assets of the layout")

    parameter(:engine_uuid, :formData, :string, "ID of layout's engine", required: true)

    response(200, "Ok", Schema.ref(:LayoutAndEngine))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec create(Plug.Conn.t(), map) :: Plug.Conn.t()
  def create(conn, %{"engine_uuid" => engine_uuid} = params) do
    current_user = conn.assigns[:current_user]

    with %Engine{} = engine <- Document.get_engine(engine_uuid),
         %Layout{} = layout <- Document.create_layout(current_user, engine, params) do
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

    parameter(:page, :query, :string, "Page number")

    response(200, "Ok", Schema.ref(:LayoutIndex))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec index(Plug.Conn.t(), map) :: Plug.Conn.t()
  def index(conn, params) do
    current_user = conn.assigns[:current_user]

    with %{
           entries: layouts,
           page_number: page_number,
           total_pages: total_pages,
           total_entries: total_entries
         } <- Document.layout_index(current_user, params) do
      conn
      |> render("index.json",
        doc_layouts: layouts,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      )
    end
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

    # parameters do
    #   id(:path, :string, "layout id", required: true)
    #   layout(:body, Schema.ref(:LayoutRequest), "Layout to be updated", required: true)
    # end

    consumes("multipart/form-data")

    parameter(:id, :path, :string, "layout id", required: true)

    parameter(:name, :formData, :string, "Layout's name", required: true)

    parameter(:description, :formData, :string, "Layout description", required: true)

    parameter(:width, :formData, :string, "Layout width", required: true)

    parameter(:height, :formData, :string, "Layout height", required: true)

    parameter(:unit, :formData, :string, "Layout dimension unit", required: true)

    parameter(:slug, :formData, :string, "Name of slug to be used")

    parameter(:slug_file, :formData, :file, "Slug file to upload")

    parameter(:screenshot, :formData, :file, "Screenshot to upload", required: true)

    parameter(:assets, :formData, :list, "IDs of assets of the layout")

    parameter(:engine_uuid, :formData, :string, "ID of layout's engine", required: true)

    response(200, "Ok", Schema.ref(:ShowLayout))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec update(Plug.Conn.t(), map) :: Plug.Conn.t()
  def update(conn, %{"id" => uuid} = params) do
    current_user = conn.assigns[:current_user]

    with %Layout{} = layout <- Document.get_layout(uuid),
         %Layout{} = layout <- Document.update_layout(layout, current_user, params) do
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
    current_user = conn.assigns[:current_user]

    with %Layout{} = layout <- Document.get_layout(uuid),
         {:ok, %Layout{}} <- Document.delete_layout(layout, current_user) do
      conn
      |> render("layout.json", doc_layout: layout)
    end
  end

  @doc """
  Delete a Layout Asset.
  """
  swagger_path :delete_layout_asset do
    PhoenixSwagger.Path.delete("/layouts/{id}/assets/{a_id}")
    summary("Delete a Layout Asset")
    description("API to delete a layout-asset association")

    parameters do
      id(:path, :string, "layout id", required: true)
      a_id(:path, :string, "asset id", required: true)
    end

    response(200, "Ok", Schema.ref(:ShowLayout))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec delete_layout_asset(Plug.Conn.t(), map) :: Plug.Conn.t()
  def delete_layout_asset(conn, %{"id" => l_uuid, "a_id" => a_uuid}) do
    current_user = conn.assigns[:current_user]

    with %LayoutAsset{} = layout_asset <- Document.get_layout_asset(l_uuid, a_uuid),
         {:ok, %LayoutAsset{}} <- Document.delete_layout_asset(layout_asset, current_user),
         %Layout{} = layout <- Document.show_layout(l_uuid) do
      conn
      |> render("show.json", doc_layout: layout)
    end
  end
end
