defmodule WraftDocWeb.Api.V1.PermissionController do
  use WraftDocWeb, :controller
  use PhoenixSwagger

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.{
    Authorization,
    Authorization.Permission
  }

  def swagger_definitions do
    %{
      PermissionRequest:
        swagger_schema do
          title("Permission Request")
          description("Create permission request.")

          properties do
            role_uuid(:string, "Role ID", required: true)
            resource_uuid(:string, "Resource ID", required: true)
          end

          example(%{
            resource_uuid: "kjb3476123",
            role_uuid: "jb3123jbiu1293"
          })
        end,
      Permission:
        swagger_schema do
          title("A permission JSON response")
          description("JSON response for a permission")
          type(:map)

          example(%{
            Flow_create: ["user", "admin"]
          })
        end,
      PermissionIndex:
        swagger_schema do
          properties do
            permissions(Schema.ref(:Permission))
            page_number(:integer, "Page number")
            total_pages(:integer, "Total number of pages")
            total_entries(:integer, "Total number of contents")
          end

          example(%{
            permissions: [
              %{
                Flow_create: [
                  %{
                    name: "user",
                    id: "5613hbkqew67134",
                    permission: %{
                      id: "1237-gh34813",
                      resource_id: "nnbj12378123m"
                    }
                  },
                  %{
                    name: "admin",
                    id: "87612-1230981230123",
                    permission: %{
                      id: "1237-glkn348-123",
                      resource_id: "  bnjcasd-123ln13248-kjcns"
                    }
                  }
                ]
              },
              %{
                Flow_delete: [
                  %{
                    name: "user",
                    id: "5613hbkqew67134",
                    permission: %{
                      id: "1237-gh34813",
                      resource_id: "nnbj12378123m"
                    }
                  }
                ]
              }
            ]
          })
        end
    }
  end

  @doc """
  Add a permission.
  """
  swagger_path :create do
    post("/permissions")
    summary("Create permission")
    description("Create permission API")

    parameters do
      resource(:body, Schema.ref(:PermissionRequest), "Permission to be created", required: true)
    end

    response(200, "Ok", Schema.ref(:Permission))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(400, "Bad Request", Schema.ref(:Error))
  end

  @spec create(Plug.Conn.t(), map) :: Plug.Conn.t()
  def create(conn, params) do
    permission = Authorization.create_permission(params)
    render(conn, "create.json", permission: permission)
  end

  @doc """
  Resource index.
  """
  swagger_path :index do
    get("/permissions")
    summary("Permission index")
    description("API to get the list of all permissions created so far")

    response(200, "Ok", Schema.ref(:PermissionIndex))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(400, "Bad Request", Schema.ref(:Error))
  end

  @spec index(Plug.Conn.t(), map) :: Plug.Conn.t()
  def index(conn, _params) do
    current_user = conn.assigns.current_user
    permissions = Authorization.list_permissions(current_user)
    render(conn, "index.json", permissions: permissions)
  end

  @doc """
  Delete a permission.
  """
  swagger_path :delete do
    PhoenixSwagger.Path.delete("/permissions/{id}")
    summary("Delete a permission")
    description("API to remove a permission")

    parameters do
      id(:path, :string, "permission id", required: true)
    end

    response(200, "Ok", Schema.ref(:Resource))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(400, "Bad Request", Schema.ref(:Error))
  end

  @spec delete(Plug.Conn.t(), map) :: Plug.Conn.t()
  def delete(conn, %{"id" => uuid}) do
    with %Permission{} = permission <- Authorization.get_permission(uuid),
         {:ok, %Permission{}} <- Authorization.delete_permission(permission) do
      render(conn, "delete.json", permission: permission)
    end
  end
end
