defmodule WraftDocWeb.Api.V1.ContentTypeRoleController do
  use WraftDocWeb, :controller
  use PhoenixSwagger
  action_fallback(WraftDocWeb.FallbackController)
  alias WraftDoc.Document

  def swagger_definitions do
    %{
      ContentTypeRole:
        swagger_schema do
          title("Content type role")
          description("List of roles under content type")

          properties do
            id(:string, "ID of the content_type")
            description(:string, "Content Type's description", required: true)
            layout_uuid(:string, "ID of the layout selected", required: true)
            flow_uuid(:string, "ID of the flow selected", required: true)
            color(:string, "Hex code of color")

            prefix(:string, "Prefix to be used for generating Unique ID for contents",
              required: true
            )
          end

          example(%{
            color: "null",
            decription: "highway to hell",
            id: "54a29859-f09e-4da9-9682-7f63d1a75fdc",
            name: "document",
            prefix: "sx",
            role: [
              %{
                id: "73d7a4c4-ec8c-4717-a540-6c05100a9904",
                name: "superadmin 2"
              }
            ]
          })
        end,
      ContentType:
        swagger_schema do
          title("Create Content Type")
          description("create a new content type")

          properties do
            id(:string, "ID of the content_type")
            description(:string, "Content Type's description", required: true)
            layout_uuid(:string, "ID of the layout selected", required: true)
            flow_uuid(:string, "ID of the flow selected", required: true)
            color(:string, "Hex code of color")

            prefix(:string, "Prefix to be used for generating Unique ID for contents",
              required: true
            )
          end
        end,
      ContentTypeRole:
        swagger_schema do
          title("create content role")
          description("create a new content type role api")

          properties do
            name(:string, "Name of the role")
          end
        end
    }
  end

  swagger_path :show do
    get("/content_type/{id}")
    summary("show all the content type role")
    description("API to list all the roles under the content_type")

    parameters do
      id(:path, :string, "id", required: true)
    end

    response(200, "Ok", Schema.ref(:ContentTypeRole))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not Found", Schema.ref(:Error))
  end

  def show(conn, %{"id" => uuid}) do
    content_type_role = Document.get_content_type_roles(uuid)

    conn
    |> render("show.json", content_type_role: content_type_role)
  end

  swagger_path :create do
    post("/content_role/{id}")
    summary("Create the content type role")
    description("Content Type role creation api")

    parameters do
      id(:path, :string, "id", required: true)
      role(:body, Schema.ref(:ContentTypeRole), "Content Type Role API")
    end

    response(200, "Ok", Schema.ref(:ContentTypeRole))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not Found", Schema.ref(:Error))
  end

  def create(conn, %{"id" => uuid} = params) do
    content_type_role = Document.create_content_role(uuid, params)

    conn
    |> render("show_content_type.json", content_type_role: content_type_role)
  end
end
