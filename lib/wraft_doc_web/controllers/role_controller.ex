defmodule WraftDocWeb.Api.V1.RoleController do
  use WraftDocWeb, :controller
  use PhoenixSwagger

  alias WraftDoc.{Account, Account.Role}
  action_fallback(WraftDocWeb.FallbackController)

  def swagger_definitions do
    %{
      RoleRequest:
        swagger_schema do
          title("Role request")
          description("Create role request")

          properties do
            name(:string, "Role name", required: true)
          end

          example(%{name: "hr"})
        end,
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

  swagger_path :create do
    post("/roles")
    summary("Create roles ")
    description(" Create specified roles in organisation")

    parameters do
      role(:body, Schema.ref(:RoleRequest), "Role to be created", required: true)
    end

    response(200, "Ok", Schema.ref(:Role))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(400, "Bad Request", Schema.ref(:Error))
  end

  def create(conn, params) do
    user = conn.assigns.current_user

    with %Role{} = role <- Account.create_role(user, params) do
      render(conn, "show.json", role: role)
    end
  end

  swagger_path :show do
    get("/roles/{id}")
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
    current_user = conn.assigns.current_user

    with %Role{} = role <- Account.show_role(current_user, id) do
      render(conn, "show.json", role: role)
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/roles/{id}")
    summary("Delete a role")
    description("API to delete a role")

    parameters do
      id(:path, :string, "role id", required: true)
    end

    response(200, "Ok", Schema.ref(:Role))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(400, "Bad Request", Schema.ref(:Error))
  end

  @spec delete(Plug.Conn.t(), map) :: Plug.Conn.t()
  def delete(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    with %Role{} = role <- Account.show_role(user, id),
         {:ok, %Role{}} <- Account.delete_role(role) do
      render(conn, "show.json", role: role)
    end
  end
end
