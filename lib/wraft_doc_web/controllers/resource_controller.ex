defmodule WraftDocWeb.Api.V1.ResourceController do
  use WraftDocWeb, :controller
  use PhoenixSwagger

  action_fallback(WraftDocWeb.FallbackController)
  alias WraftDoc.{Authorization, Authorization.Resource}

  def swagger_definitions do
    %{
      ResourceRequest:
        swagger_schema do
          title("Resource Request")
          description("Create resource request.")

          properties do
            category(:string, "Category's name", required: true)
            action(:string, "Action name", required: true)
          end

          example(%{
            category: "Flow",
            action: "create"
          })
        end,
      Resource:
        swagger_schema do
          title("Resource")
          description("A Resource")

          properties do
            id(:string, "The ID of the layout", required: true)
            category(:string, "Name of the category", required: true)
            action(:string, "Name of the action", required: true)
          end

          example(%{
            id: "1232148nb3478",
            category: "Flow",
            action: "create"
          })
        end,
      Resources:
        swagger_schema do
          title("Resource list")
          type(:array)
          items(Schema.ref(:Resource))
        end,
      ResourceIndex:
        swagger_schema do
          properties do
            resources(Schema.ref(:Resources))
            page_number(:integer, "Page number")
            total_pages(:integer, "Total number of pages")
            total_entries(:integer, "Total number of contents")
          end

          example(%{
            resources: [
              %{
                id: "1232148nb3478",
                category: "Flow",
                action: "create"
              },
              %{
                id: "137ykjbefd987132",
                category: "Flow",
                action: "update"
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
  Create a layout.
  """
  swagger_path :create do
    post("/resources")
    summary("Create resource")
    description("Create resource API")

    parameters do
      resource(:body, Schema.ref(:ResourceRequest), "Resource to be created", required: true)
    end

    response(200, "Ok", Schema.ref(:Resource))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(400, "Bad Request", Schema.ref(:Error))
  end

  @spec create(Plug.Conn.t(), map) :: Plug.Conn.t()
  def create(conn, params) do
    with {:ok, %Resource{} = resource} <- Authorization.create_resource(params) do
      render(conn, "create.json", resource: resource)
    end
  end

  @doc """
  Resource index.
  """
  swagger_path :index do
    get("/resources")
    summary("Resource index")
    description("API to get the list of all resources created so far")

    parameter(:page, :query, :string, "Page number")

    response(200, "Ok", Schema.ref(:ResourceIndex))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(400, "Bad Request", Schema.ref(:Error))
  end

  @spec index(Plug.Conn.t(), map) :: Plug.Conn.t()
  def index(conn, _params) do
    resources = Authorization.list_resources()
    render(conn, "index.json", resources: resources)
  end

  @doc """
  Show a resource.
  """
  swagger_path :show do
    get("/resources/{id}")
    summary("Show a resource")
    description("API to show details of a resource")

    parameters do
      id(:path, :string, "resource id", required: true)
    end

    response(200, "Ok", Schema.ref(:Resource))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(400, "Bad Request", Schema.ref(:Error))
  end

  @spec show(Plug.Conn.t(), map) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    with %Resource{} = resource <- Authorization.get_resource(id) do
      render(conn, "create.json", resource: resource)
    end
  end

  @doc """
  Update a resource.
  """
  swagger_path :update do
    put("/resources/{id}")
    summary("Update a resource")
    description("API to update a resource")

    parameters do
      id(:path, :string, "resource id", required: true)
      resource(:body, Schema.ref(:ResourceRequest), "Resource to be updated", required: true)
    end

    response(200, "Ok", Schema.ref(:Resource))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(400, "Bad Request", Schema.ref(:Error))
  end

  @spec update(Plug.Conn.t(), map) :: Plug.Conn.t()
  def update(conn, %{"id" => id} = params) do
    with %Resource{} = resource <- Authorization.get_resource(id),
         {:ok, %Resource{} = resource} <- Authorization.update_resource(resource, params) do
      render(conn, "create.json", resource: resource)
    end
  end

  @doc """
  Delete a Resource.
  """
  swagger_path :delete do
    PhoenixSwagger.Path.delete("/resources/{id}")
    summary("Delete a resource")
    description("API to delete a resource")

    parameters do
      id(:path, :string, "resource id", required: true)
    end

    response(200, "Ok", Schema.ref(:Resource))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(400, "Bad Request", Schema.ref(:Error))
  end

  @spec delete(Plug.Conn.t(), map) :: Plug.Conn.t()
  def delete(conn, %{"id" => id}) do
    with %Resource{} = resource <- Authorization.get_resource(id),
         {:ok, %Resource{}} <- Authorization.delete_resource(resource) do
      render(conn, "create.json", resource: resource)
    end
  end
end
