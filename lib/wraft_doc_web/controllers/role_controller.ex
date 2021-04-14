defmodule WraftDocWeb.Api.V1.RoleController do
  use WraftDocWeb, :controller
  use PhoenixSwagger

  alias WraftDoc.Account.Role
  alias WraftDoc.Document
  action_fallback(WraftDocWeb.FallbackController)

  def swagger_definitions do
    %{
      Role:
        swagger_schema do
          title("Content type under Role")
          description("all the content type under the role")

          properties do
            id(:string, "Id of the role")
            name(:string, "Name of the role")
          end
        end,
      ContentType:
        swagger_schema do
          title("Content type")
          description("all the content type")

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
        end
    }
  end

  swagger_path :show do
    get("/role/{id}")
    summary("show all the content type under the role")
    description("API to list all the content type under the role")

    parameters do
      id(:path, :string, "id", required: true)
    end

    response(200, "Ok", Schema.ref(:Role))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not Found", Schema.ref(:Error))
  end

  def show(conn, %{"id" => id}) do
    role = Document.get_content_type_under_roles(id)

    conn
    |> render("show.json", role: role)
  end

  swagger_path :delete_content_type_role do
    delete("/role/{id}/content/{content_id}")
    summary("show all the content type under the role")
    description("API to list all the content type under the role")

    parameters do
      id(:path, :string, "id", required: true)
      content_id(:path, :string, "content_id", required: true)
    end

    response(200, "Ok", Schema.ref(:Role))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not Found", Schema.ref(:Error))
  end

  def delete_content_type_role(conn, %{"id" => id, "content_id" => content_id}) do
    with %Role{} = role <- Document.get_role_of_content_type(id, content_id),
         %Role{} = role <- Document.delete_role_of_the_content_type(role) do
      conn |> render("role.json", role: role)
    end
  end
end
