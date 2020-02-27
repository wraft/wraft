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
end
