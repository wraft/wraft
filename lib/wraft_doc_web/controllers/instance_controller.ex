defmodule WraftDocWeb.Api.V1.InstanceController do
  use WraftDocWeb, :controller
  use PhoenixSwagger

  action_fallback(WraftDocWeb.FallbackController)
  alias WraftDoc.{Document, Document.Instance, Document.ContentType, Enterprise, Enterprise.Flow}

  def swagger_definitions do
    %{
      Content:
        swagger_schema do
          title("Content")
          description("A content, which is then used to generate the out files.")

          properties do
            id(:string, "The ID of the content", required: true)
            instance_id(:string, "A unique ID generated for the content")
            raw(:string, "Raw data of the content")
            serialized(:map, "Serialized data of the content")
            inserted_at(:string, "When was the engine inserted", format: "ISO-8601")
            updated_at(:string, "When was the engine last updated", format: "ISO-8601")
          end

          example(%{
            id: "1232148nb3478",
            instance_id: "OFFL01",
            raw: "Content",
            serialized: %{title: "Title of the content", body: "Body of the content"},
            updated_at: "2020-01-21T14:00:00Z",
            inserted_at: "2020-02-21T14:00:00Z"
          })
        end,
      ContentRequest:
        swagger_schema do
          title("Content Request")
          description("Content creation request")

          properties do
            raw(:string, "Content raw data", required: true)
            serialized(:string, "Content serialized data")
            flow_uuid(:string, "Flow id", required: true)
          end

          example(%{
            raw: "Content data",
            serialized: %{title: "Title of the content", body: "Body of the content"},
            flow_uuid: "kjb12389k23eyg"
          })
        end,
      ContentAndContentTypeAndFlow:
        swagger_schema do
          title("Content and its Content Type")
          description("A content and its content type")

          properties do
            content(Schema.ref(:Content))
            content_type(Schema.ref(:ContentType))
            state(Schema.ref(:Flow))
          end

          example(%{
            content: %{
              id: "1232148nb3478",
              instance_id: "OFFL01",
              raw: "Content",
              serialized: %{title: "Title of the content", body: "Body of the content"},
              updated_at: "2020-01-21T14:00:00Z",
              inserted_at: "2020-02-21T14:00:00Z"
            },
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
              updated_at: "2020-01-21T14:00:00Z",
              inserted_at: "2020-02-21T14:00:00Z"
            },
            state: %{
              uuid: "1232148nb3478",
              state: "published",
              order: 1
            }
          })
        end
    }
  end

  @doc """
  Create an instance.
  """
  swagger_path :create do
    post("/content_types/{c_type_id}/contents")
    summary("Create a content")
    description("Create content API")

    parameters do
      c_type_id(:path, :string, "content type id", required: true)
      content(:body, Schema.ref(:ContentRequest), "Content to be created", required: true)
    end

    response(200, "Ok", Schema.ref(:ContentAndContentTypeAndFlow))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec create(Plug.Conn.t(), map) :: Plug.Conn.t()
  def create(conn, %{"c_type_id" => c_type_uuid, "flow_uuid" => flow_uuid} = params) do
    current_user = conn.assigns[:current_user]

    with %ContentType{} = c_type <- Document.get_content_type(c_type_uuid),
         %Flow{} = flow <- Enterprise.get_flow(flow_uuid),
         %Instance{} = content <- Document.create_instance(current_user, c_type, flow, params) do
      conn
      |> render(:create, content: content)
    end
  end
end
