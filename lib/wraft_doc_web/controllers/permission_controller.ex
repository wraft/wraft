defmodule WraftDocWeb.Api.V1.PermissionController do
  use WraftDocWeb, :controller
  use PhoenixSwagger

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.Authorization

  def swagger_definitions do
    %{
      Permission:
        swagger_schema do
          title("A permission JSON response")
          description("JSON response for a permission")
          type(:map)

          example(%{
            name: "layout:index",
            resource: "Layout",
            acion: "Index"
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
    permissions = Authorization.list_permissions()
    render(conn, "index.json", permissions: permissions)
  end
end
