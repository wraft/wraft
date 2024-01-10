defmodule WraftDocWeb.Api.V1.ContentTypeRoleController do
  use WraftDocWeb, :controller
  use PhoenixSwagger

  plug WraftDocWeb.Plug.Authorized,
    create: "content_type_role:manage",
    delete: "content_type_role:delete"

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.Document
  alias WraftDoc.Document.ContentTypeRole

  def swagger_definitions do
    %{
      ContentTypeRole:
        swagger_schema do
          title("Content type role")
          description("List of roles under content type")

          properties do
            content_type_id(:string, "ID of the content_type")
            role_id(:string, "ID of the role type")
          end
        end,
      DeleteContentTypeRole:
        swagger_schema do
          title("Delete Content Type")
          description("delete a content type role")

          properties do
            id(:string, "ID of the content_type_role")
          end
        end
    }
  end

  swagger_path :create do
    post("/content_type_roles")
    summary("Create the content type role")
    description("Content Type role creation api")

    parameters do
      content_type_role(:body, Schema.ref(:ContentTypeRole), "Content Type Role API")
    end

    response(200, "Ok", Schema.ref(:ContentTypeRole))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not Found", Schema.ref(:Error))
  end

  def create(conn, params) do
    content_type_role = Document.create_content_type_role(params)

    render(conn, "create_content_type.json", content_type_role: content_type_role)
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/content_type_roles/{id}")
    summary("Delete the content type role")
    description("Delete Type role creation api")

    parameters do
      id(:path, :string, "content_type_role_id", required: true)
    end

    response(200, "Ok", Schema.ref(:DeleteContentTypeRole))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not Found", Schema.ref(:Error))
  end

  def delete(conn, %{"id" => id}) do
    with %ContentTypeRole{} = content_type_role <- Document.get_content_type_and_role(id),
         %ContentTypeRole{} = content_type_role <-
           Document.delete_content_type_role(content_type_role) do
      render(conn, "show_content_type.json", content_type_role: content_type_role)
    end
  end
end
