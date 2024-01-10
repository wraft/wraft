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

          properties do
            id(:string, "The ID of the permission", required: true)
            name(:string, "Permissions's name", required: true)
            action(:string, "Permission's action", required: true)
          end

          example(%{
            id: "1232148nb3478",
            name: "layout:index",
            acion: "Index",
            resource: "Layout"
          })
        end,
      PermissionByResource:
        swagger_schema do
          title("Permissions by resource")
          description("Permissions grouped by resource")
          type(:map)

          example(%{
            "Layout" => [
              %{id: "1232148nb3478", name: "layout:index", acion: "Index"},
              %{id: "2374679278373", name: "layout:manage", acion: "Manage"}
            ]
          })
        end,
      ResourceIndex:
        swagger_schema do
          title("Resources index")
          description("All resources we have in Wraft")
          type(:list)

          example(["Layout", "Content Type", "Data Template"])
        end
    }
  end

  @doc """
  Permissions index, grouped by resource.
  """
  swagger_path :index do
    get("/permissions")
    summary("Permission index")
    description("API to get the list of all permissions created so far")

    parameters do
      name(:query, :string, "Permission name")
      resource(:query, :string, "Name of Resource")
    end

    response(200, "Ok", Schema.ref(:PermissionByResource))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(400, "Bad Request", Schema.ref(:Error))
  end

  @spec index(Plug.Conn.t(), map) :: Plug.Conn.t()
  def index(conn, params) do
    permissions_by_resource = Authorization.list_permissions(params)
    render(conn, "index.json", permissions_by_resource: permissions_by_resource)
  end

  @doc """
  Lists all the resources we have in Wraft.
  """
  swagger_path :resource_index do
    get("/resources")
    summary("Resource index")
    description("API to get the list of all resources we have in Wraft")

    response(200, "Ok", Schema.ref(:ResourceIndex))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(400, "Bad Request", Schema.ref(:Error))
  end

  @spec resource_index(Plug.Conn.t(), map) :: Plug.Conn.t()
  def resource_index(conn, _params) do
    permissions = Authorization.list_resources()

    conn
    |> put_resp_header("content-type", "application/json")
    |> send_resp(200, Jason.encode!(permissions))
  end
end
