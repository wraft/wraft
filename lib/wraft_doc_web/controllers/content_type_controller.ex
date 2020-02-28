defmodule WraftDocWeb.Api.V1.ContentTypeController do
  use WraftDocWeb, :controller
  use PhoenixSwagger

  action_fallback(WraftDocWeb.FallbackController)
  alias WraftDoc.{Document, Document.ContentType}

  def swagger_definitions do
    %{
      ContentTypeRequest:
        swagger_schema do
          title("Content Type Request")
          description("Create content type request.")

          properties do
            name(:string, "Content Type's name", required: true)
            description(:string, "Content Type's description")
            fields(:map, "Dynamic fields and their datatype")
            layout_id(:integer, "ID of the layout selected")
          end

          example(%{
            name: "Offer letter",
            description: "An offer letter",
            fields: %{
              name: "string",
              position: "string",
              joining_date: "date",
              approved_by: "string"
            },
            layout_id: 1
          })
        end,
      ContentType:
        swagger_schema do
          title("Content Type")
          description("A Content Type.")

          properties do
            id(:string, "The ID of the content type", required: true)
            name(:string, "Content Type's name", required: true)
            description(:string, "Content Type's description")
            fields(:map, "Dynamic fields and their datatype")
            inserted_at(:string, "When was the user inserted", format: "ISO-8601")
            updated_at(:string, "When was the user last updated", format: "ISO-8601")
          end

          example(%{
            id: "1232148nb3478",
            name: "Offer letter",
            description: "An offer letter",
            fields: %{
              name: "string",
              position: "string",
              joining_date: "date",
              approved_by: "string"
            },
            updated_at: "2020-01-21T14:00:00Z",
            inserted_at: "2020-02-21T14:00:00Z"
          })
        end,
      ContentTypeAndLayout:
        swagger_schema do
          title("Content Type and Layout")
          description("Content Type to be used for the generation of a document.")

          properties do
            id(:string, "The ID of the content type", required: true)
            name(:string, "Content Type's name", required: true)
            description(:string, "Content Type's description")
            fields(:map, "Dynamic fields and their datatype")
            layout(Schema.ref(:Layout))
            inserted_at(:string, "When was the user inserted", format: "ISO-8601")
            updated_at(:string, "When was the user last updated", format: "ISO-8601")
          end

          example(%{
            id: "1232148nb3478",
            name: "Offer letter",
            description: "An offer letter",
            fields: %{
              name: "string",
              position: "string",
              joining_date: "date",
              approved_by: "string"
            },
            layout: %{
              id: "1232148nb3478",
              name: "Official Letter",
              description: "An official letter",
              width: 40.0,
              height: 20.0,
              unit: "cm",
              slug: "Pandoc",
              updated_at: "2020-01-21T14:00:00Z",
              inserted_at: "2020-02-21T14:00:00Z"
            },
            updated_at: "2020-01-21T14:00:00Z",
            inserted_at: "2020-02-21T14:00:00Z"
          })
        end,
      ContentTypesAndLayouts:
        swagger_schema do
          title("Content Types and their Layouts")
          description("All content types that have been created and their layouts")
          type(:array)
          items(Schema.ref(:ContentTypeAndLayout))
        end,
      ShowContentType:
        swagger_schema do
          title("Content Type and all its details")
          description("API to show a content type and all its details")

          properties do
            content_type(Schema.ref(:ContentTypeAndLayout))
            creator(Schema.ref(:User))
          end

          example(%{
            content_type: %{
              id: "1232148nb3478",
              name: "Offer letter",
              description: "An offer letter",
              fields: %{
                name: "string",
                position: "string",
                joining_date: "date",
                approved_by: "string"
              },
              layout: %{
                id: "1232148nb3478",
                name: "Official Letter",
                description: "An official letter",
                width: 40.0,
                height: 20.0,
                unit: "cm",
                slug: "Pandoc",
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
  Create a content type.
  """
  swagger_path :create do
    post("/content_types")
    summary("Create content type")
    description("Create content type API")

    parameters do
      content_type(:body, Schema.ref(:ContentTypeRequest), "Content Type to be created",
        required: true
      )
    end

    response(200, "Ok", Schema.ref(:ContentTypeAndLayout))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec create(Plug.Conn.t(), map) :: Plug.Conn.t()
  def create(conn, params) do
    current_user = conn.assigns[:current_user]

    with %ContentType{} = content_type <- Document.create_content_type(current_user, params) do
      conn
      |> render(:create, content_type: content_type)
    end
  end

  @doc """
  Content Type index.
  """
  swagger_path :index do
    get("/content_types")
    summary("Content Type index")
    description("API to get the list of all content types created so far")

    response(200, "Ok", Schema.ref(:ContentTypesAndLayouts))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec index(Plug.Conn.t(), map) :: Plug.Conn.t()
  def index(conn, _params) do
    content_types = Document.content_type_index()

    conn
    |> render("index.json", content_types: content_types)
  end

  @doc """
  Show a Content Type.
  """
  swagger_path :show do
    get("/content_types/{id}")
    summary("Show a Content Type")
    description("API to show details of a content type")

    parameters do
      id(:path, :string, "content type id", required: true)
    end

    response(200, "Ok", Schema.ref(:ShowContentType))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not Found", Schema.ref(:Error))
  end

  @spec show(Plug.Conn.t(), map) :: Plug.Conn.t()
  def show(conn, %{"id" => uuid}) do
    with %ContentType{} = content_type <- Document.show_content_type(uuid) do
      conn
      |> render("show.json", content_type: content_type)
    end
  end

  @doc """
  Update a Content Type.
  """
  swagger_path :update do
    put("/content_types/{id}")
    summary("Update a Content Type")
    description("API to update a content type")

    parameters do
      id(:path, :string, "content type id", required: true)
      layout(:body, Schema.ref(:ContentTypeRequest), "Content Type to be updated", required: true)
    end

    response(200, "Ok", Schema.ref(:ShowContentType))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(404, "Not Found", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec update(Plug.Conn.t(), map) :: Plug.Conn.t()
  def update(conn, %{"id" => uuid} = params) do
    with %ContentType{} = content_type <- Document.get_content_type(uuid),
         %ContentType{} = content_type <- Document.update_content_type(content_type, params) do
      conn
      |> render("show.json", content_type: content_type)
    end
  end

  @doc """
  Delete a Content Type.
  """
  swagger_path :delete do
    PhoenixSwagger.Path.delete("/content_types/{id}")
    summary("Delete a Content Type")
    description("API to delete a content type")

    parameters do
      id(:path, :string, "content type id", required: true)
    end

    response(200, "Ok", Schema.ref(:ContentType))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(404, "Not Found", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec delete(Plug.Conn.t(), map) :: Plug.Conn.t()
  def delete(conn, %{"id" => uuid}) do
    with %ContentType{} = content_type <- Document.get_content_type(uuid),
         {:ok, %ContentType{}} <- Document.delete_content_type(content_type) do
      conn
      |> render("content_type.json", content_type: content_type)
    end
  end
end
