defmodule WraftDocWeb.Api.V1.RoleController do
  use WraftDocWeb, :controller
  use PhoenixSwagger

  alias WraftDoc.Account
  alias WraftDoc.Account.Role
  alias WraftDoc.Enterprise

  action_fallback(WraftDocWeb.FallbackController)

  def swagger_definitions do
    %{
      RoleRequest:
        swagger_schema do
          title("Role request")
          description("Create role request")

          properties do
            name(:string, "Role name", required: true)
            permissions(:list, "Permissions of the role")
          end

          example(%{
            name: "Editor",
            permissions: ["layout:index", "layout:show", "layout:create", "layout:update"]
          })
        end,
      Role:
        swagger_schema do
          title("Content type under Role")
          description("all the content type under the role")

          properties do
            id(:string, "Id of the role")
            name(:string, "Name of the role")
            permissions(:list, "Permissions of the role")
          end

          example(%{
            id: "9322d1a5-4f44-463d-b4a5-ce797a029ac2",
            name: "Editor",
            permissions: ["layout:index", "layout:show", "layout:create", "layout:update"]
          })
        end,
      ListOfRoles:
        swagger_schema do
          title("Roles array")
          description("List of existing Roles")
          type(:array)
          items(Schema.ref(:Role))
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

  swagger_path :index do
    get("/roles")
    summary("List of roles")
    description("All roles in an organisation")

    response(200, "Ok", Schema.ref(:ListOfRoles))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  def index(conn, _params) do
    current_user = conn.assigns[:current_user]
    roles = Enterprise.roles_in_users_organisation(current_user)
    render(conn, "index.json", roles: roles)
  end

  swagger_path :update do
    put("/roles/{id}")
    summary("Update role")
    description("Update role name and permissions")

    parameters do
      id(:path, :string, "role id", required: true)
      role(:body, Schema.ref(:RoleRequest), "Role to be updated", required: true)
    end

    response(200, "Ok", Schema.ref(:Role))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not found", Schema.ref(:Error))
  end

  @spec update(Plug.Conn.t(), map) :: Plug.Conn.t()
  def update(conn, %{"id" => uuid} = params) do
    current_user = conn.assigns[:current_user]

    with %Role{} = role <- Account.get_role(current_user, uuid),
         %Role{} = role <- Account.update_role(role, params) do
      render(conn, "show.json", role: role)
    end
  end
end
