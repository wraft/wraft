defmodule WraftDocWeb.Api.V1.ContentTypeRoleController do
  use WraftDocWeb, :controller
  use OpenApiSpex.ControllerSpecs

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.ContentTypes
  alias WraftDoc.ContentTypes.ContentTypeRole
  alias WraftDocWeb.Schemas.ContentTypeRole, as: ContentTypeRoleSchema
  alias WraftDocWeb.Schemas.Error

  tags(["Content Type Roles"])

  operation(:create,
    summary: "Create the content type role",
    description: "Content Type role creation api",
    request_body:
      {"Content Type Role API", "application/json", ContentTypeRoleSchema.ContentTypeRoleRequest},
    responses: [
      ok: {"Ok", "application/json", ContentTypeRoleSchema.ContentTypeRoleResponse},
      unauthorized: {"Unauthorized", "application/json", Error},
      not_found: {"Not Found", "application/json", Error}
    ]
  )

  def create(conn, params) do
    content_type_role = ContentTypes.create_content_type_role(params)

    render(conn, "create_content_type.json", content_type_role: content_type_role)
  end

  operation(:delete,
    summary: "Delete the content type role",
    description: "Delete Type role creation api",
    parameters: [
      id: [in: :path, type: :string, description: "content_type_role_id", required: true]
    ],
    responses: [
      ok: {"Ok", "application/json", ContentTypeRoleSchema.DeleteContentTypeRole},
      unauthorized: {"Unauthorized", "application/json", Error},
      not_found: {"Not Found", "application/json", Error}
    ]
  )

  def delete(conn, %{"id" => id}) do
    with %ContentTypeRole{} = content_type_role <- ContentTypes.get_content_type_and_role(id),
         %ContentTypeRole{} = content_type_role <-
           ContentTypes.delete_content_type_role(content_type_role) do
      render(conn, "show_content_type.json", content_type_role: content_type_role)
    end
  end
end
