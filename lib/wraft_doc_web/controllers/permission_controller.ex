defmodule WraftDocWeb.Api.V1.PermissionController do
  use WraftDocWeb, :controller
  use PhoenixSwagger

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.{
    Authorization,
    Authorization.Permission,
    Account,
    Account.Role,
    Authorization.Resource
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
            resources: [
              %{
                Flow_create: ["user", "admin"]
              },
              %{
                Flow_delete: ["admin"]
              }
            ],
            page_number: 1,
            total_pages: 2,
            total_entries: 15
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
  def create(conn, %{"role_uuid" => role_uuid, "resource_uuid" => resource_uuid}) do
    with %Resource{} = resource <- Authorization.get_resource(resource_uuid),
         %Role{} = role <- Account.get_role_from_uuid(role_uuid),
         %Permission{} = permission <-
           Authorization.create_permission(resource, role) do
      conn |> render("create.json", permission: permission)
    end
  end

  @doc """
  Resource index.
  """
  swagger_path :index do
    get("/permissions")
    summary("Permission index")
    description("API to get the list of all permissions created so far")

    parameter(:page, :query, :string, "Page number")

    response(200, "Ok", Schema.ref(:PermissionIndex))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(400, "Bad Request", Schema.ref(:Error))
  end

  @spec index(Plug.Conn.t(), map) :: Plug.Conn.t()
  def index(conn, params) do
    with %{
           entries: resources,
           page_number: page_number,
           total_pages: total_pages,
           total_entries: total_entries
         } <- Authorization.permission_index(params) do
      conn
      |> render("index.json",
        resources: resources,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      )
    end
  end

  # @doc """
  # Show a resource.
  # """
  # swagger_path :show do
  #   get("/resources/{id}")
  #   summary("Show a resource")
  #   description("API to show details of a resource")

  #   parameters do
  #     id(:path, :string, "resource id", required: true)
  #   end

  #   response(200, "Ok", Schema.ref(:Resource))
  #   response(401, "Unauthorized", Schema.ref(:Error))
  #   response(400, "Bad Request", Schema.ref(:Error))
  # end

  # @spec show(Plug.Conn.t(), map) :: Plug.Conn.t()
  # def show(conn, %{"id" => uuid}) do
  #   with %Resource{} = resource <- Authorization.get_resource(uuid) do
  #     conn
  #     |> render("create.json", resource: resource)
  #   end
  # end

  # @doc """
  # Delete a Resource.
  # """
  # swagger_path :delete do
  #   PhoenixSwagger.Path.delete("/resources/{id}")
  #   summary("Delete a resource")
  #   description("API to delete a resource")

  #   parameters do
  #     id(:path, :string, "resource id", required: true)
  #   end

  #   response(200, "Ok", Schema.ref(:Resource))
  #   response(422, "Unprocessable Entity", Schema.ref(:Error))
  #   response(401, "Unauthorized", Schema.ref(:Error))
  #   response(400, "Bad Request", Schema.ref(:Error))
  # end

  # @spec delete(Plug.Conn.t(), map) :: Plug.Conn.t()
  # def delete(conn, %{"id" => uuid}) do
  #   with %Resource{} = resource <- Authorization.get_resource(uuid),
  #        {:ok, %Resource{}} <- Authorization.delete_resource(resource) do
  #     conn
  #     |> render("create.json", resource: resource)
  #   end
  # end
end
