defmodule WraftDocWeb.Api.V1.RepositoryController do
  use WraftDocWeb, :controller
  use PhoenixSwagger

  alias WraftDoc.Storage
  alias WraftDoc.Storage.Repository

  action_fallback(WraftDocWeb.FallbackController)

  def swagger_definitions do
    %{
      StorageItem:
        swagger_schema do
          title("Storage Item")
          description("A file or folder in the storage system.")

          properties do
            id(:string, "The ID of the storage item", required: true, format: "uuid")
            name(:string, "Name of the item", required: true)
            display_name(:string, "Display name of the item")
            item_type(:string, "Type of item", enum: ["file", "folder"])
            path(:string, "Path to the item")
            mime_type(:string, "MIME type of the item")
            size(:integer, "Size in bytes")
            is_folder(:boolean, "Whether the item is a folder")
            inserted_at(:string, "Creation timestamp", format: "ISO-8601")
            updated_at(:string, "Last update timestamp", format: "ISO-8601")
          end

          example(%{
            id: "550e8400-e29b-41d4-a716-446655440000",
            name: "contract.pdf",
            display_name: "Contract Agreement",
            item_type: "file",
            path: "/Contracts/Q4",
            mime_type: "application/pdf",
            size: 1024,
            is_folder: false,
            inserted_at: "2023-01-10T14:00:00Z",
            updated_at: "2023-01-12T09:15:00Z"
          })
        end,
      Repository:
        swagger_schema do
          title("Repository")
          description("A storage repository containing files and folders.")

          properties do
            id(:string, "The ID of the repository", required: true, format: "uuid")
            name(:string, "Name of the repository", required: true)
            description(:string, "Description of the repository")
            status(:string, "Status of the repository", enum: ["active", "inactive"])
            storage_limit(:integer, "Storage limit in bytes")
            current_storage_used(:integer, "Current storage used in bytes")
            item_count(:integer, "Number of items in the repository")
            creator_id(:string, "ID of the user who created the repository", format: "uuid")

            organisation_id(:string, "ID of the organisation this repository belongs to",
              format: "uuid"
            )

            inserted_at(:string, "Creation timestamp", format: "ISO-8601")
            updated_at(:string, "Last update timestamp", format: "ISO-8601")
          end

          example(%{
            id: "550e8400-e29b-41d4-a716-446655440000",
            name: "My Documents",
            description: "My personal storage repository",
            status: "active",
            storage_limit: 104_857_600,
            current_storage_used: 52_428_800,
            item_count: 100,
            creator_id: "550e8400-e29b-41d4-a716-446655440000",
            organisation_id: "550e8400-e29b-41d4-a716-446655440000",
            inserted_at: "2023-01-10T14:00:00Z",
            updated_at: "2023-01-12T09:15:00Z"
          })
        end,
      RepositoryCreateParams:
        swagger_schema do
          title("Repository Create Parameters")
          description("Parameters for creating a new repository")

          properties do
            name(:string, "Name of the repository", required: true)
            description(:string, "Description of the repository")
            storage_limit(:integer, "Storage limit in bytes")

            status(:string, "Status of the repository",
              enum: ["active", "inactive"],
              default: "active"
            )
          end

          example(%{
            name: "My Documents",
            description: "My personal storage repository",
            storage_limit: 104_857_600,
            status: "active"
          })
        end,
      RepositoryUpdateParams:
        swagger_schema do
          title("Repository Update Parameters")
          description("Parameters for updating an existing repository")

          properties do
            name(:string, "Name of the repository")
            description(:string, "Description of the repository")
            storage_limit(:integer, "Storage limit in bytes")
            status(:string, "Status of the repository", enum: ["active", "inactive"])
          end

          example(%{
            name: "Updated Repository Name",
            description: "Updated description",
            storage_limit: 209_715_200,
            status: "active"
          })
        end,
      CounterPartiesList:
        swagger_schema do
          title("Counter Parties List")
          description("List of counter parties")

          properties do
            data(:array, "List of counter parties", items: Schema.ref(:CounterParty))
            total(:integer, "Total number of counter parties")
            page(:integer, "Current page number")
            per_page(:integer, "Items per page")
          end

          example(%{
            data: [
              %{
                id: "550e8400-e29b-41d4-a716-446655440000",
                name: "ABC Corporation",
                email: "contact@abc.com",
                type: "organization"
              }
            ],
            total: 1,
            page: 1,
            per_page: 10
          })
        end,
      CounterParty:
        swagger_schema do
          title("Counter Party")
          description("A counter party entity")

          properties do
            id(:string, "The ID of the counter party", required: true, format: "uuid")
            name(:string, "Name of the counter party", required: true)
            email(:string, "Email of the counter party")
            type(:string, "Type of counter party", enum: ["individual", "organization"])
            inserted_at(:string, "Creation timestamp", format: "ISO-8601")
            updated_at(:string, "Last update timestamp", format: "ISO-8601")
          end

          example(%{
            id: "550e8400-e29b-41d4-a716-446655440000",
            name: "ABC Corporation",
            email: "contact@abc.com",
            type: "organization",
            inserted_at: "2023-01-10T14:00:00Z",
            updated_at: "2023-01-12T09:15:00Z"
          })
        end,
      CreateSignatureRequest:
        swagger_schema do
          title("Create Signature Request")
          description("Parameters for creating a signature request")

          properties do
            document_id(:string, "ID of the document to be signed",
              required: true,
              format: "uuid"
            )

            signer_email(:string, "Email of the signer", required: true)
            signer_name(:string, "Name of the signer", required: true)
            message(:string, "Message to include with the signature request")
            due_date(:string, "Due date for the signature", format: "ISO-8601")

            signature_type(:string, "Type of signature",
              enum: ["electronic", "digital"],
              default: "electronic"
            )
          end

          example(%{
            document_id: "550e8400-e29b-41d4-a716-446655440000",
            signer_email: "john.doe@example.com",
            signer_name: "John Doe",
            message: "Please sign this document",
            due_date: "2023-12-31T23:59:59Z",
            signature_type: "electronic"
          })
        end,
      Error:
        swagger_schema do
          title("Error")
          description("Error response")

          properties do
            error(:string, "Error message", required: true)
            details(:string, "Additional error details")
          end

          example(%{
            error: "Resource not found",
            details: "The requested repository does not exist"
          })
        end
    }
  end

  def index(conn, _params) do
    repositories = Storage.list_repositories()
    render(conn, "index.json", repositories: repositories)
  end

  swagger_path :create do
    post("/api/repositories")
    summary("Create a repository")
    description("Creates a new storage repository")
    operation_id("createRepository")
    consumes("application/json")
    produces("application/json")
    tag("Repositories")

    parameters do
      repository(:body, Schema.ref(:RepositoryCreateParams), "Repository creation parameters",
        required: true
      )
    end

    response(201, "Created", Schema.ref(:Repository))
    response(400, "Bad Request", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
  end

  def create(conn, %{"repository" => repository_params}) do
    with {:ok, %Repository{} = repository} <- Storage.create_repository(repository_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", "/api/repositories/#{repository.id}")
      |> render(:show, repository: repository)
    end
  end

  swagger_path :show do
    get("/api/repositories/{id}")
    summary("Get repository details")
    description("Returns detailed information about a specific repository")
    operation_id("getRepository")
    produces("application/json")
    tag("Repositories")

    parameters do
      id(:path, :string, "ID of the repository to fetch", required: true, format: "uuid")
    end

    response(200, "OK", Schema.ref(:Repository))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not Found", Schema.ref(:Error))
  end

  def show(conn, %{"id" => id}) do
    repository = Storage.get_repository!(id)
    render(conn, :show, repository: repository)
  end

  swagger_path :check_setup do
    get("/api/repository/check")
    summary("Check repository setup")

    description("""
    Checks if the current user has at least one repository in their current organization.
    Returns the list of repositories if any exist.
    """)

    operation_id("checkRepositorySetup")
    produces("application/json")
    tag("Repositories")

    response(200, "OK", Schema.ref(:Repository))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  def check_setup(conn, _params) do
    user_id = conn.assigns.current_user.id
    organisation_id = conn.assigns.current_user.current_org_id

    repositories = Storage.list_repositories_by_user_and_organisation(user_id, organisation_id)

    render(conn, :index, repositories: repositories)
  end

  swagger_path :setup_repository do
    put("/api/repository/setup")
    summary("Setup default repository")

    description("""
    Creates a default repository for the current user in their current organization.
    The repository will have a randomly generated name and default storage limits.
    """)

    operation_id("setupDefaultRepository")
    produces("application/json")
    tag("Repositories")

    response(201, "Created", Schema.ref(:Repository))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
  end

  def setup_repository(conn, _params) do
    user_id = conn.assigns.current_user.id
    organisation_id = conn.assigns.current_user.current_org_id

    repo_name = "Repository_#{Base.encode16(:crypto.strong_rand_bytes(8), case: :lower)}"

    repository_params = %{
      "name" => repo_name,
      "description" => "Auto-generated repository for user setup",
      "storage_limit" => 10_000_000_000,
      "current_storage_used" => 0,
      "item_count" => 0,
      "status" => "active",
      "creator_id" => user_id,
      "organisation_id" => organisation_id
    }

    with {:ok, %Repository{} = repository} <- Storage.create_repository(repository_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", "/api/repositories/#{repository.id}")
      |> render(:show, repository: repository)
    end
  end

  swagger_path :update do
    patch("/api/repositories/{id}")
    put("/api/repositories/{id}")
    summary("Update repository")
    description("Updates an existing repository")
    operation_id("updateRepository")
    consumes("application/json")
    produces("application/json")
    tag("Repositories")

    parameters do
      id(:path, :string, "ID of the repository to update", required: true, format: "uuid")

      repository(:body, Schema.ref(:RepositoryUpdateParams), "Repository update parameters",
        required: true
      )
    end

    response(200, "OK", Schema.ref(:Repository))
    response(400, "Bad Request", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not Found", Schema.ref(:Error))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
  end

  def update(conn, %{"id" => id, "repository" => repository_params}) do
    repository = Storage.get_repository!(id)

    with {:ok, %Repository{} = repository} <-
           Storage.update_repository(repository, repository_params) do
      render(conn, :show, repository: repository)
    end
  end

  def delete(conn, %{"id" => id}) do
    repository = Storage.get_repository!(id)

    with {:ok, %Repository{}} <- Storage.delete_repository(repository) do
      send_resp(conn, :no_content, "")
    end
  end
end
