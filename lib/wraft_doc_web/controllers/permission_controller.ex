defmodule WraftDocWeb.Api.V1.PermissionController do
  use WraftDocWeb, :controller
  use OpenApiSpex.ControllerSpecs

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.Authorization
  alias WraftDocWeb.Schemas.Error
  alias WraftDocWeb.Schemas.Permission, as: PermissionSchema

  tags(["Permissions"])

  operation(:index,
    summary: "Permission index",
    description: "API to get the list of all permissions created so far",
    parameters: [
      name: [in: :query, type: :string, description: "Permission name"],
      resource: [in: :query, type: :string, description: "Name of Resource"]
    ],
    responses: [
      ok: {"Ok", "application/json", PermissionSchema.PermissionByResource},
      unauthorized: {"Unauthorized", "application/json", Error},
      bad_request: {"Bad Request", "application/json", Error}
    ]
  )

  @spec index(Plug.Conn.t(), map) :: Plug.Conn.t()
  def index(conn, params) do
    permissions_by_resource = Authorization.list_permissions(params)
    render(conn, "index.json", permissions_by_resource: permissions_by_resource)
  end

  operation(:resource_index,
    summary: "Resource index",
    description: "API to get the list of all resources we have in Wraft",
    responses: [
      ok: {"Ok", "application/json", PermissionSchema.ResourceIndex},
      unauthorized: {"Unauthorized", "application/json", Error},
      bad_request: {"Bad Request", "application/json", Error}
    ]
  )

  @spec resource_index(Plug.Conn.t(), map) :: Plug.Conn.t()
  def resource_index(conn, _params) do
    permissions = Authorization.list_resources()

    conn
    |> put_resp_header("content-type", "application/json")
    |> send_resp(200, Jason.encode!(permissions))
  end
end
