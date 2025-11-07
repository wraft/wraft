defmodule WraftDocWeb.Api.V1.RepositoryController do
  @moduledoc """
  API endpoints for managing document repositories.

  Repositories are isolated storage containers that organize documents and folders
  for users and organizations. Each repository has configurable storage limits
  and access controls.

  ## Repository Lifecycle
  - Created via `/api/repositories` POST
  - Managed via CRUD operations
  - Automatically setup for new users via `/api/repository/setup`
  """
  use WraftDocWeb, :controller
  use PhoenixSwagger

  alias WraftDoc.Storages
  alias WraftDoc.Storages.Repository

  plug WraftDocWeb.Plug.AddActionLog
  plug WraftDocWeb.Plug.FeatureFlagCheck, feature: :repository

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

          description("""
          Parameters for creating a new repository.

          Required fields:
          - name: Must be unique within the organization
          - storage_limit: In bytes (1GB = 1073741824 bytes)
          """)

          properties do
            name(:string, "Name of the repository", required: true, example: "Legal Documents")
            description(:string, "Description of the repository", example: "All legal contracts")
            storage_limit(:integer, "Storage limit in bytes", example: 107_374_182_400)

            status(:string, "Status of the repository",
              enum: ["active", "inactive"],
              default: "active",
              example: "active"
            )
          end

          example(%{
            name: "Legal Documents",
            description: "All legal contracts and agreements",
            storage_limit: 107_374_182_400,
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
      RepositoriesList:
        swagger_schema do
          title("Repositories List")
          description("List of repositories")

          properties do
            data(:array, "List of repositories", items: Schema.ref(:Repository))
          end

          example(%{
            data: [
              %{
                id: "550e8400-e29b-41d4-a716-446655440000",
                name: "Company Documents",
                description: "Official company documents",
                status: "active",
                storage_limit: 107_374_182_400,
                current_storage_used: 32_212_254_720,
                item_count: 1250,
                creator_id: "550e8400-e29b-41d4-a716-446655440000",
                organisation_id: "550e8400-e29b-41d4-a716-446655440000",
                inserted_at: "2023-03-15T09:30:00Z",
                updated_at: "2023-06-20T14:22:00Z"
              }
            ]
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

  swagger_path :index do
    get("/repositories")
    summary("List repositories")

    description("""
    Returns a paginated list of repositories accessible to the current user.

    ### Filtering
    - Filter by status: `?status=active`
    - Filter by organization: `?organization_id=UUID`

    ### Sorting
    - Sort by name: `?sort=name`
    - Sort by storage used: `?sort=storage_used`
    """)

    operation_id("listRepositories")
    produces("application/json")
    tag("Repositories")

    response(200, "OK", Schema.ref(:RepositoriesList))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  def index(conn, _params) do
    repositories = Storages.list_repositories()
    render(conn, "index.json", repositories: repositories)
  end

  swagger_path :create do
    post("/repositories")
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
    response(403, "Unauthorized", Schema.ref(:Error))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
  end

  def create(conn, %{"repository" => repository_params}) do
    with {:ok, %Repository{} = repository} <- Storages.create_repository(repository_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", "/api/repositories/#{repository.id}")
      |> render(:show, repository: repository)
    end
  end

  swagger_path :show do
    get("/repositories/{id}")
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
    repository = Storages.get_repository!(id)
    render(conn, :show, repository: repository)
  end

  swagger_path :check_setup do
    get("/repository/check")
    summary("Check repository setup status")

    description("""
    Checks if the current user has any repositories in their organization.

    ### Typical Responses:
    - 200 with empty array: No repositories exist (user needs to setup)
    - 200 with repositories: User has existing repositories

    Used during user onboarding to determine if default repository creation is needed.
    """)

    operation_id("checkRepositorySetup")
    produces("application/json")
    tag("Repositories")

    response(200, "OK", Schema.ref(:RepositoriesList),
      example: %{
        data: [
          %{
            id: "550e8400-e29b-41d4-a716-446655440000",
            name: "My Documents",
            description: "Personal storage",
            status: "active",
            storage_limit: 10_737_418_240,
            current_storage_used: 5_368_709_120,
            item_count: 42,
            creator_id: "550e8400-e29b-41d4-a716-446655440001",
            organisation_id: "550e8400-e29b-41d4-a716-446655440002",
            inserted_at: "2023-01-01T00:00:00Z",
            updated_at: "2023-01-01T00:00:00Z"
          }
        ]
      }
    )

    response(200, "No Repositories", Schema.ref(:RepositoriesList),
      example: %{
        data: []
      }
    )

    response(401, "Unauthorized", Schema.ref(:Error),
      example: %{
        error: "Unauthorized",
        details: "Authentication required"
      }
    )
  end

  def check_setup(conn, _params) do
    user_id = conn.assigns.current_user.id
    organisation_id = conn.assigns.current_user.current_org_id

    repositories = Storages.list_repositories_by_user_and_organisation(user_id, organisation_id)

    render(conn, :index, repositories: repositories)
  end

  swagger_path :setup_repository do
    put("/repository/setup")
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

    with {:ok, %Repository{} = repository} <- Storages.create_repository(repository_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", "/api/repositories/#{repository.id}")
      |> render(:show, repository: repository)
    end
  end

  swagger_path :update do
    patch("/repositories/{id}")
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
    repository = Storages.get_repository!(id)

    with {:ok, %Repository{} = repository} <-
           Storages.update_repository(repository, repository_params) do
      render(conn, :show, repository: repository)
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/repositories/{id}")
    summary("Delete repository")
    description("Permanently deletes a repository")
    operation_id("deleteRepository")
    produces("application/json")
    tag("Repositories")

    parameters do
      id(:path, :string, "ID of the repository to delete", required: true, format: "uuid")
    end

    response(204, "No Content")
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not Found", Schema.ref(:Error))
  end

  def delete(conn, %{"id" => id}) do
    repository = Storages.get_repository!(id)

    with {:ok, %Repository{}} <- Storages.delete_repository(repository) do
      send_resp(conn, :no_content, "")
    end
  end

  swagger_path :export do
    post("/repositories/export")
    summary("Export repository as ZIP")

    description(
      "Exports all files in the repository as a ZIP archive and returns it as a binary download"
    )

    operation_id("exportRepository")
    produces("application/zip")
    tag("Repositories")

    parameters do
      file_name(:body, :string, "Optional file name for the ZIP archive")
    end

    response(200, "ZIP file returned successfully", Schema.ref(:FileDownloadResponse))
    response(403, "Unauthorized", Schema.ref(:Error))
    response(404, "Repository not found", Schema.ref(:Error))
  end

  def export(conn, params) do
    current_user = conn.assigns[:current_user]

    with %{name: repository_name} = _repository <-
           Storages.get_latest_repository(current_user.current_org_id) do
      Storages.repository_export_worker(
        current_user,
        Map.get(params, "file_name", repository_name)
      )

      json(conn, %{
        message: "Repository export started. You will receive an email when it’s ready."
      })
    end
  end
end
