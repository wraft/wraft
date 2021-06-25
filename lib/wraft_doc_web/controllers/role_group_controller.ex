defmodule WraftDocWeb.Api.V1.RoleGroupController do
  use WraftDocWeb, :controller
  plug(WraftDocWeb.Plug.Authorized)
  plug(WraftDocWeb.Plug.AddActionLog)
  action_fallback(WraftDocWeb.FallbackController)

  use PhoenixSwagger
  alias WraftDoc.{Account, Account.RoleGroup}

  def swagger_definitions do
    %{
      RoleGroupRequest:
        swagger_schema do
          title("Role group request")
          description("Role group details")

          properties do
            name(:string, "Role group name", required: true)
            description(:string, "Role group description")
            roles(:array, "Lists of role id s")
          end

          example(%{
            name: "Chatura",
            description: "Team containg 4 roles on management",
            roles: [
              %{role_id: "sdfsdf-541sdfsd-2256sdf1-1221sd5f"},
              %{role_id: "sdfsdf-541sdfsd-2256sdf1-1221sd5f"},
              %{role_id: "sdfsdf-541sdfsd-2256sdf1-1221sd5f"}
            ]
          })
        end,
      RoleGroup:
        swagger_schema do
          title("Role group")
          description("Role group details")

          properties do
            name(:string, "Role group name")
            description(:string, "Role group description")
            roles(:array, "List of roles")
            inserted_at(:string, "inserted at")
            updated_at(:string, "Updated at")
          end

          example(%{
            name: "Chatura",
            description: "Team containg 4 roles on management",
            roles: [
              %{name: "manager"},
              %{name: "CTO"},
              %{name: "CEO"}
            ]
          })
        end
    }
  end

  swagger_path :create do
    post("/role_groups")
    summary("/create a role group")
    description("/creates a role group")

    parameters do
      role_group(:body, Schema.ref(:RoleGroupRequest), "Role group to create", required: true)
    end

    response(200, "Updated", Schema.ref(:RoleGroup))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  def create(conn, params) do
    with %RoleGroup{} = role_group <- Account.create_role_group(conn.assigns.current_user, params) do
      render(conn, "show.json", role_group: role_group)
    end
  end

  swagger_path :show do
    get("/role_groups/{id}")
    summary("get a role group")

    parameters do
      id(:path, :string, "Role group id", required: true)
    end

    response(200, "Created", Schema.ref(:RoleGroup))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  def show(conn, %{"id" => id}) do
    with %RoleGroup{} = role_group <- Account.show_role_group(conn.assigns.current_user, id) do
      render(conn, "show.json", role_group: role_group)
    end
  end

  swagger_path :update do
    put("/role_groups/{id}")
    summary("/update a role group")
    description("/updates a role group")

    parameters do
      id(:path, :string, "Role group id", required: true)
      role_group(:body, Schema.ref(:RoleGroupRequest), "Role group to update", required: true)
    end

    response(200, "Updated", Schema.ref(:RoleGroup))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  def update(conn, %{"id" => id} = params) do
    with %RoleGroup{} = role_group <- Account.get_role_group(conn.assigns.current_user, id),
         %RoleGroup{} = role_group <- Account.update_role_group(role_group, params) do
      render(conn, "show.json", role_group: role_group)
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/role_groups/{id}")
    description("Delete a role group")

    parameters do
      id(:path, :string, "Role group id", required: true)
    end

    response(204, "Deleted", Schema.ref(:RoleGroup))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  def delete(conn, %{"id" => id}) do
    with %RoleGroup{} = role_group <- Account.get_role_group(conn.assigns.current_user, id),
         {:ok, role_group} <- Account.delete_role_group(role_group) do
      render(conn, "role_group.json", role_group: role_group)
    end
  end
end
