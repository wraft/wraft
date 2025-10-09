defmodule WraftDocWeb.Api.V1.StorageItemController do
  @moduledoc """
  API endpoints for managing storage items (files and folders).

  Provides CRUD operations for storage items including:
  - Listing items with pagination and sorting
  - Creating files and folders
  - Renaming items
  - Moving items
  - Deleting items
  - Navigation and breadcrumbs

  ## Storage Hierarchy
  - Root level
    - Repositories (logical containers)
      - Folders
        - Files
  """
  use WraftDocWeb, :controller
  use PhoenixSwagger
  require Logger

  alias WraftDoc.Storage
  alias WraftDoc.Storage.Repository
  alias WraftDoc.Storage.StorageAssets
  alias WraftDoc.Storage.StorageItem
  alias WraftDoc.Storage.StorageItems

  import WraftDocWeb.ErrorHelpers

  action_fallback(WraftDocWeb.FallbackController)

  def swagger_definitions do
    %{
      StorageItem:
        swagger_schema do
          title("Storage Item")
          description("A file or folder in the storage system")

          properties do
            id(:string, "The ID of the storage item", required: true, format: "uuid")
            name(:string, "Name of the item", required: true)
            display_name(:string, "Display name of the item")
            item_type(:string, "Type of item", enum: ["file", "folder"])
            path(:string, "Path to the item")
            mime_type(:string, "MIME type of the item")
            file_extension(:string, "File extension")
            size(:integer, "Size in bytes")
            is_folder(:boolean, "Whether the item is a folder")
            depth_level(:integer, "Depth level in the folder hierarchy")
            materialized_path(:string, "Materialized path for hierarchy")
            version_number(:integer, "Version number of the item")
            is_current_version(:boolean, "Whether this is the current version")
            classification_level(:string, "Security classification level")
            content_extracted(:boolean, "Whether content has been extracted")
            thumbnail_generated(:boolean, "Whether thumbnail has been generated")
            download_count(:integer, "Number of times downloaded")
            last_accessed_at(:string, "Last access timestamp", format: "ISO-8601")
            metadata(:object, "Additional metadata")
            parent_id(:string, "ID of parent folder", format: "uuid")
            repository_id(:string, "ID of the repository", format: "uuid")
            creator_id(:string, "ID of the creator", format: "uuid")
            organisation_id(:string, "ID of the organisation", format: "uuid")
            inserted_at(:string, "Creation timestamp", format: "ISO-8601")
            updated_at(:string, "Last update timestamp", format: "ISO-8601")
            assets(:array, "Associated storage assets", items: Schema.ref(:StorageAsset))
          end

          example(%{
            id: "550e8400-e29b-41d4-a716-446655440000",
            name: "contract.pdf",
            display_name: "Contract Agreement",
            item_type: "file",
            path: "/Contracts/Q4/contract.pdf",
            mime_type: "application/pdf",
            file_extension: "pdf",
            size: 1_024_000,
            is_folder: false,
            depth_level: 2,
            materialized_path: "/Contracts/Q4/",
            version_number: 1,
            is_current_version: true,
            classification_level: "public",
            content_extracted: true,
            thumbnail_generated: true,
            download_count: 5,
            last_accessed_at: "2023-01-15T10:30:00Z",
            metadata: %{},
            parent_id: "550e8400-e29b-41d4-a716-446655440001",
            repository_id: "550e8400-e29b-41d4-a716-446655440002",
            creator_id: "550e8400-e29b-41d4-a716-446655440003",
            organisation_id: "550e8400-e29b-41d4-a716-446655440004",
            inserted_at: "2023-01-10T14:00:00Z",
            updated_at: "2023-01-12T09:15:00Z",
            assets: []
          })
        end,
      StorageAsset:
        swagger_schema do
          title("Storage Asset")
          description("A physical storage asset associated with a storage item")

          properties do
            id(:string, "The ID of the storage asset", required: true, format: "uuid")
            filename(:string, "Original filename", required: true)
            storage_key(:string, "Storage backend key")
            storage_backend(:string, "Storage backend type")
            file_size(:integer, "File size in bytes")
            mime_type(:string, "MIME type")

            processing_status(:string, "Processing status",
              enum: ["pending", "processing", "completed", "failed"]
            )

            upload_completed_at(:string, "Upload completion timestamp", format: "ISO-8601")
            checksum_sha256(:string, "SHA256 checksum")
            thumbnail_path(:string, "Path to thumbnail")
            preview_path(:string, "Path to preview")
            url(:string, "Access URL")
            inserted_at(:string, "Creation timestamp", format: "ISO-8601")
            updated_at(:string, "Last update timestamp", format: "ISO-8601")
          end

          example(%{
            id: "550e8400-e29b-41d4-a716-446655440000",
            filename: "contract.pdf",
            storage_key: "uploads/2023/01/contract_abc123.pdf",
            storage_backend: "s3",
            file_size: 1_024_000,
            mime_type: "application/pdf",
            processing_status: "completed",
            upload_completed_at: "2023-01-10T14:05:00Z",
            checksum_sha256: "abc123def456...",
            thumbnail_path: "/thumbnails/contract_thumb.jpg",
            preview_path: "/previews/contract_preview.jpg",
            url: "https://storage.example.com/contract.pdf",
            inserted_at: "2023-01-10T14:00:00Z",
            updated_at: "2023-01-10T14:05:00Z"
          })
        end,
      # StorageStats:
      #   swagger_schema do
      #     title("Storage Statistics")
      #     description("Statistics for a folder or root directory")

      #     properties do
      #       total_items(:integer, "Total number of items")
      #       total_size(:integer, "Total size in bytes")
      #       file_count(:integer, "Number of files")
      #       folder_count(:integer, "Number of folders")
      #       last_updated(:string, "Last update timestamp", format: "ISO-8601")
      #     end

      #     example(%{
      #       total_items: 42,
      #       total_size: 10_485_760,
      #       file_count: 35,
      #       folder_count: 7,
      #       last_updated: "2023-01-15T10:30:00Z"
      #     })
      #   end,
      StorageItemsList:
        swagger_schema do
          title("Storage Items List")
          description("List of storage items with metadata")

          properties do
            data(:array, "List of storage items", items: Schema.ref(:StorageItem))
            # breadcrumbs(:array, "Breadcrumb navigation", items: Schema.ref(:Breadcrumb))
            current_folder(Schema.ref(:CurrentFolder), "Current folder information")
            meta(Schema.ref(:ListMeta), "List metadata")
          end

          example(%{
            data: [
              %{
                id: "550e8400-e29b-41d4-a716-446655440000",
                name: "Documents",
                is_folder: true,
                size: 0,
                mime_type: "inode/directory"
              }
            ],
            breadcrumbs: [
              %{id: "root", name: "Root", path: "/"}
            ],
            current_folder: %{
              id: "550e8400-e29b-41d4-a716-446655440000",
              name: "Documents",
              is_folder: true
            },
            meta: %{
              count: 1,
              sort_by: "created",
              sort_order: "desc"
            }
          })
        end,
      Breadcrumb:
        swagger_schema do
          title("Breadcrumb")
          description("Navigation breadcrumb item")

          properties do
            id(:string, "ID of the folder", format: "uuid")
            name(:string, "Name of the folder", required: true)
            path(:string, "Path to the folder")
            is_folder(:boolean, "Whether this is a folder", default: true)
          end

          example(%{
            id: "550e8400-e29b-41d4-a716-446655440000",
            name: "Documents",
            path: "/Documents",
            is_folder: true
          })
        end,
      CurrentFolder:
        swagger_schema do
          title("Current Folder")
          description("Information about the current folder")

          properties do
            id(:string, "ID of the folder", format: "uuid")
            name(:string, "Name of the folder", required: true)
            is_folder(:boolean, "Whether this is a folder", default: true)
            path(:string, "Path to the folder")
            materialized_path(:string, "Materialized path")
          end

          example(%{
            id: "550e8400-e29b-41d4-a716-446655440000",
            name: "Documents",
            is_folder: true,
            path: "/Documents",
            materialized_path: "/Documents/"
          })
        end,
      ListMeta:
        swagger_schema do
          title("List Metadata")
          description("Metadata for list responses")

          properties do
            count(:integer, "Number of items returned")
            breadcrumbs_count(:integer, "Number of breadcrumb items")
            sort_by(:string, "Sort field used")
            sort_order(:string, "Sort order used")
            timestamp(:string, "Response timestamp", format: "ISO-8601")
          end

          example(%{
            count: 25,
            breadcrumbs_count: 3,
            sort_by: "created",
            sort_order: "desc",
            timestamp: "2023-01-15T10:30:00Z"
          })
        end,
      StorageItemCreateParams:
        swagger_schema do
          title("Storage Item Create Parameters")
          description("Parameters for creating a storage item")

          properties do
            name(:string, "Name of the item", required: true)
            display_name(:string, "Display name of the item")
            item_type(:string, "Type of item", enum: ["file", "folder"], required: true)
            path(:string, "Path to the item")
            mime_type(:string, "MIME type of the item")
            size(:integer, "Size in bytes", default: 0)
            parent_id(:string, "ID of parent folder", format: "uuid")
            metadata(:object, "Additional metadata")
          end

          example(%{
            name: "new_document.pdf",
            display_name: "New Document",
            item_type: "file",
            path: "/Documents/new_document.pdf",
            mime_type: "application/pdf",
            size: 1_024_000,
            parent_id: "550e8400-e29b-41d4-a716-446655440000",
            metadata: %{}
          })
        end,
      FolderCreateParams:
        swagger_schema do
          title("Folder Create Parameters")
          description("Parameters for creating a folder")

          properties do
            name(:string, "Name of the folder", required: true)
            path(:string, "Path to the folder", required: true)
            parent_id(:string, "ID of parent folder", format: "uuid")
          end

          example(%{
            name: "New Folder",
            path: "/Documents/New Folder",
            parent_id: "550e8400-e29b-41d4-a716-446655440000"
          })
        end,
      StorageItemUpdateParams:
        swagger_schema do
          title("Storage Item Update Parameters")
          description("Parameters for updating a storage item")

          properties do
            name(:string, "Name of the item")
            display_name(:string, "Display name of the item")
            metadata(:object, "Additional metadata")
          end

          example(%{
            name: "updated_document.pdf",
            display_name: "Updated Document",
            metadata: %{category: "contracts"}
          })
        end,
      RenameParams:
        swagger_schema do
          title("Rename Parameters")
          description("Parameters for renaming a storage item")

          properties do
            new_name(:string, "New name for the item", required: true)
          end

          example(%{
            new_name: "renamed_document.pdf"
          })
        end,
      NavigationData:
        swagger_schema do
          title("Navigation Data")
          description("Storage navigation data")

          properties do
            data(Schema.ref(:NavigationItems), "Navigation items and breadcrumbs")
            meta(Schema.ref(:ListMeta), "Navigation metadata")
          end

          example(%{
            data: %{
              items: [],
              breadcrumbs: []
            },
            meta: %{
              count: 0,
              timestamp: "2023-01-15T10:30:00Z"
            }
          })
        end,
      DeleteStorageItemResponse:
        swagger_schema do
          title("Delete Storage Item Response")
          description("Response for successful storage item deletion")

          properties do
            message(:string, "Success message", example: "Storage item marked for deletion")

            id(:string, "ID of deleted item",
              format: "uuid",
              example: "550e8400-e29b-41d4-a716-446655440000"
            )
          end
        end,
      NavigationItems:
        swagger_schema do
          title("Navigation Items")
          description("Items and breadcrumbs for navigation")

          properties do
            items(:array, "List of storage items", items: Schema.ref(:StorageItem))
            # breadcrumbs(:array, "Breadcrumb navigation", items: Schema.ref(:Breadcrumb))
          end

          example(%{
            items: [],
            breadcrumbs: []
          })
        end
    }
  end

  swagger_path :index do
    get("/storage/items")
    summary("List storage items")

    description("""
    Lists storage items with pagination, sorting and filtering.

    ### Path Variations
    - `/storage/items` - Root level items
    - `/storage/items?parent_id=UUID` - Items within a specific folder
    - `/storage/items?repository_id=UUID` - Items within a specific repository

    ### Sorting
    Supported sort fields: name, created, updated, size, type
    """)

    operation_id("listStorageItems")
    produces("application/json")
    tag("Storage Items")

    parameters do
      parent_id(:query, :string, "Parent folder ID to list contents", format: "uuid")
      repository_id(:query, :string, "Repository ID to filter by", format: "uuid")

      limit(:query, :integer, "Number of items to return (1-1000)",
        default: 100,
        minimum: 1,
        maximum: 1000
      )

      offset(:query, :integer, "Number of items to skip", default: 0, minimum: 0)

      sort_by(:query, :string, "Sort field",
        enum: ["name", "created", "updated", "size", "type"],
        default: "created"
      )

      sort_order(:query, :string, "Sort direction", enum: ["asc", "desc"], default: "desc")
    end

    response(200, "OK", Schema.ref(:StorageItemsList))
    response(400, "Bad Request", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not Found", Schema.ref(:Error))
  end

  @doc """
  Lists storage items with optional filtering.

  ## Route
  GET /api/v1/storage/items

  ## Parameters
  - parent_id: Filter by parent folder UUID
  - repository_id: Filter by repository UUID
  - limit: Pagination limit (default: 100)
  - offset: Pagination offset
  - sort_by: Field to sort by (name, created, updated, size, type)
  - sort_order: Sort direction (asc, desc)

  ## Examples
      # List root items
      GET /api/v1/storage/items

      # List folder contents
      GET /api/v1/storage/items?parent_id=550e8400-e29b-41d4-a716-446655440000
  """

  def index(conn, params) do
    current_user = conn.assigns[:current_user]
    organisation_id = current_user.current_org_id

    with :ok <- StorageItems.validate_uuid_param(params, "parent_id"),
         :ok <- StorageItems.validate_uuid_param(params, "repository_id"),
         {:ok, storage_items} <-
           StorageItems.process_index_request(params, current_user, organisation_id) do
      render(conn, "index.json", storage_items: storage_items)
    end
  end

  swagger_path :breadcrumbs do
    get("/storage/items/{id}/breadcrumbs")
    summary("Get breadcrumb navigation")
    description("Gets breadcrumb navigation for a storage item")
    operation_id("getStorageItemBreadcrumbs")
    produces("application/json")
    tag("Storage Items")

    parameters do
      id(:path, :string, "ID of the storage item", required: true, format: "uuid")
    end

    response(200, "OK", %{
      type: :object,
      properties: %{
        data: %{
          type: :array,
          items: Schema.ref(:Breadcrumb),
          description: "Breadcrumb navigation items"
        }
      }
    })

    response(400, "Bad Request", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not Found", Schema.ref(:Error))
  end

  @doc """
  Gets breadcrumb navigation for a storage item.
  """
  def breadcrumbs(conn, %{"id" => id}) do
    current_user = conn.assigns[:current_user]

    with :ok <- StorageItems.validate_uuid_param(%{"id" => id}, "id"),
         breadcrumbs <-
           StorageItems.get_storage_item_breadcrumb_navigation(id, current_user.current_org_id) do
      render(conn, "breadcrumbs.json", breadcrumbs: breadcrumbs)
    end
  end

  swagger_path :navigation do
    get("/storage/items/navigation")
    summary("Get navigation structure")

    description("""
    Returns combined folder contents and breadcrumbs for efficient navigation.

    ### Typical Flow
    1. Client loads root navigation
    2. User clicks into folder
    3. Client requests navigation for that folder
    """)

    operation_id("getStorageNavigation")
    produces("application/json")
    tag("Storage Items")

    parameters do
      parent_id(:query, :string, "Parent folder ID", format: "uuid")

      limit(:query, :integer, "Number of items to return",
        default: 100,
        minimum: 1,
        maximum: 1000
      )

      offset(:query, :integer, "Number of items to skip", default: 0, minimum: 0)
    end

    response(200, "OK", Schema.ref(:NavigationData))
    response(400, "Bad Request", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @doc """
  Gets navigation data including items and breadcrumbs.

  ## Route
  GET /api/v1/storage/items/navigation

  ## Parameters
  - parent_id: Optional folder UUID to navigate into

  ## Examples
      # Root navigation
      GET /api/v1/storage/items/navigation

      # Folder navigation
      GET /api/v1/storage/items/navigation?parent_id=550e8400-e29b-41d4-a716-446655440000
  """
  def navigation(conn, params) do
    current_user = conn.assigns[:current_user]

    with :ok <- StorageItems.validate_uuid_param(params, "parent_id"),
         {:ok, navigation_data} <-
           params
           |> Map.get("parent_id")
           |> StorageItems.handle_navigation(current_user.current_org_id, params) do
      render(conn, "navigation.json", navigation_data: navigation_data)
    end
  end

  swagger_path :create do
    post("/storage/items")
    summary("Create a storage item")
    description("Creates a new storage item (file or folder)")
    operation_id("createStorageItem")
    consumes("application/json")
    produces("application/json")
    tag("Storage Items")

    parameters do
      storage_item(
        :body,
        Schema.ref(:StorageItemCreateParams),
        "Storage item creation parameters",
        required: true
      )
    end

    response(201, "Created", Schema.ref(:StorageItem))
    response(400, "Bad Request", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
  end

  def create(conn, params) do
    with {:ok, %StorageItem{} = storage_item} <-
           StorageItems.create_storage_item(params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", "/api/storage_items/#{storage_item}")
      |> render("show.json", storage_item: storage_item)
    end
  end

  swagger_path :create_folder do
    post("/storage/folder")
    summary("Create a folder")

    description("""
    Creates a new folder in the specified location.

    ### Path Requirements
    - Path must be absolute (start with /)
    - Parent folders must exist
    """)

    operation_id("createFolder")
    consumes("application/json")
    produces("application/json")
    tag("Storage Items")

    parameters do
      folder(:body, Schema.ref(:FolderCreateParams), "Folder creation parameters", required: true)
    end

    response(201, "Created", Schema.ref(:StorageItem))
    response(400, "Bad Request", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not Found", Schema.ref(:Error))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
  end

  @doc """
  Creates a new folder.

  ## Route
  POST /api/v1/storage/folder

  ## Parameters
  - name: Folder name (required)
  - path: Full path including folder name (required)
  - parent_id: Immediate parent folder ID (optional)

  ## Examples
      POST /api/v1/storage/folder
      {
        "folder": {
          "name": "Contracts",
          "path": "/Documents/Contracts",
          "parent_id": "550e8400-e29b-41d4-a716-446655440000"
        }
      }
  """

  def create_folder(conn, %{"folder" => folder_params}) do
    current_user = conn.assigns[:current_user]
    organisation_id = current_user.current_org_id

    Logger.info("Starting folder creation", %{
      user_id: current_user.id,
      organisation_id: organisation_id,
      folder_name: folder_params["name"],
      parent_id: folder_params["parent_id"]
    })

    folder_depth_level = StorageItems.calculate_depth_level(folder_params["path"])

    # Get the latest repository for the current organisation
    case Storage.get_latest_repository(organisation_id) do
      %Repository{} = repository ->
        Logger.info("Found repository for folder creation", %{
          repository_id: repository.id,
          organisation_id: organisation_id
        })

        # Prepare folder parameters with required metadata
        folder_params =
          folder_params
          |> Map.put("item_type", "folder")
          |> Map.put("mime_type", "inode/directory")
          |> Map.put("size", 0)
          |> Map.put("depth_level", folder_depth_level)
          |> Map.put("materialized_path", folder_params["path"])
          |> Map.put("creator_id", current_user.id)
          |> Map.put("organisation_id", organisation_id)
          |> Map.put("repository_id", repository.id)

        # Create the folder in storage
        case StorageItems.create_storage_item(folder_params) do
          {:ok, %StorageItem{} = storage_item} ->
            Logger.info("Folder created successfully", %{
              folder_id: storage_item.id,
              folder_name: storage_item.name,
              path: storage_item.path
            })

            conn
            |> put_status(:created)
            |> put_resp_header("location", "/api/v1/storage/items/#{storage_item.id}")
            |> render("show.json", storage_item: storage_item)

          {:error, %Ecto.Changeset{} = changeset} ->
            Logger.error("Failed to create folder", %{
              errors: Ecto.Changeset.traverse_errors(changeset, &translate_error/1),
              organisation_id: organisation_id
            })

            conn
            |> put_status(:unprocessable_entity)
            |> json(%{
              error: "Invalid folder data",
              details: Ecto.Changeset.traverse_errors(changeset, &translate_error/1)
            })
        end

      nil ->
        Logger.warning("No repositories found for organisation", %{
          organisation_id: organisation_id
        })

        conn
        |> put_status(:not_found)
        |> json(%{
          error: "No repository found",
          message: "No repository exists for this organisation"
        })
    end
  end

  swagger_path :show do
    get("/storage/items/{id}")
    summary("Get storage item details")
    description("Returns detailed information about a specific storage item")
    operation_id("getStorageItem")
    produces("application/json")
    tag("Storage Items")

    parameters do
      id(:path, :string, "ID of the storage item to fetch", required: true, format: "uuid")
    end

    response(200, "OK", Schema.ref(:StorageItem))
    response(400, "Bad Request", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not Found", Schema.ref(:Error))
  end

  def show(conn, %{"id" => id}) do
    current_user = conn.assigns[:current_user]
    organisation_id = current_user.current_org_id

    with :ok <- StorageItems.validate_uuid_param(%{"id" => id}, "id"),
         %StorageItem{} = storage_item <-
           StorageItems.get_storage_item_by_org(id, organisation_id) do
      storage_assets = StorageAssets.get_storage_assets_for_item(storage_item.id)

      render(conn, "storage_item.json",
        storage_item: storage_item,
        storage_assets: storage_assets
      )
    else
      nil ->
        {:error, "Storage item not found"}

      {:error, :invalid_uuid} ->
        {:error, "Invalid storage item ID format"}

      {:error, error} ->
        {:error, error}
    end
  end

  swagger_path :update do
    patch("/storage/items/{id}")
    put("/storage/items/{id}")
    summary("Update storage item")
    description("Updates an existing storage item")
    operation_id("updateStorageItem")
    consumes("application/json")
    produces("application/json")
    tag("Storage Items")

    parameters do
      id(:path, :string, "ID of the storage item to update", required: true, format: "uuid")

      storage_item(:body, Schema.ref(:StorageItemUpdateParams), "Storage item update parameters",
        required: true
      )
    end

    response(200, "OK", Schema.ref(:StorageItem))
    response(400, "Bad Request", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not Found", Schema.ref(:Error))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
  end

  def update(conn, %{"id" => id, "storage_item" => storage_item_params}) do
    storage_item = StorageItems.get_storage_item!(id)

    with {:ok, %StorageItem{} = storage_item} <-
           StorageItems.update_storage_item(storage_item, storage_item_params) do
      render(conn, :show, storage_item: storage_item)
    end
  end

  #   swagger_path :stats do
  #     get("/storage/assets/stats")
  #     summary("Get storage statistics")
  #     description("Returns statistics for a folder or root directory")
  #     operation_id("getStorageStats")
  #     produces("application/json")
  #     tag("Storage Assets")

  #     parameters do
  #       parent_id(:query, :string, "Parent folder ID", format: "uuid")
  #     end

  #     response(200, "OK", Schema.ref(:StorageStats))
  #     response(400, "Bad Request", Schema.ref(:Error))
  #     response(401, "Unauthorized", Schema.ref(:Error))
  #   end

  #   @doc """
  #   Gets statistics for a folder or root directory.
  #   """
  # def stats(conn, params) do
  #   current_user = conn.assigns[:current_user]
  #   organisation_id = current_user.current_org_id
  #   parent_id = Map.get(params, "parent_id")

  #   case validate_uuid_param(params, "parent_id") do
  #     :ok ->
  #       stats = StorageItems.get_storage_item_stats(parent_id, organisation_id)

  #       json(conn, %{
  #         data: stats
  #       })

  #     {:error, _field} ->
  #       conn
  #       |> put_status(:bad_request)
  #       |> json(%{error: "Invalid UUID format for parent_id"})
  #   end
  # end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/storage/items/{id}")
    summary("Delete storage item")
    description("Marks a storage item for deletion")
    operation_id("deleteStorageItem")
    produces("application/json")
    tag("Storage Items")

    parameters do
      id(:path, :string, "ID of the storage item to delete", required: true, format: "uuid")
    end

    response(200, "OK", Schema.ref(:DeleteStorageItemResponse))
    response(400, "Bad Request", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not Found", Schema.ref(:Error))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
  end

  def delete(conn, %{"id" => id}) do
    current_user = conn.assigns[:current_user]
    organisation_id = current_user.current_org_id

    with :ok <- StorageItems.validate_uuid_param(%{"id" => id}, "id"),
         %StorageItem{} = storage_item <-
           StorageItems.get_storage_item_by_org(id, organisation_id),
         {:ok, _} <- StorageItems.delete_storage_item(storage_item) do
      conn
      |> put_status(:ok)
      |> render("delete.json", %{
        delete: %{
          message: "Storage item marked for deletion",
          id: id
        }
      })
    else
      nil ->
        {:error, "Storage item not found"}

      {:error, :invalid_uuid} ->
        {:error, "Invalid storage item ID format"}

      {:error, _changeset} ->
        {:error, "Failed to mark storage item for deletion"}
    end
  end

  swagger_path :rename do
    post("/storage/items/{id}/rename")
    summary("Rename a storage item")

    description("""
    Renames a file or folder while maintaining all other properties.

    ### Restrictions
    - Cannot rename to existing name in same folder
    - Cannot include path separators (/)
    """)

    operation_id("renameStorageItem")
    consumes("application/json")
    produces("application/json")
    tag("Storage Items")

    parameters do
      id(:path, :string, "ID of the item to rename", required: true, format: "uuid")
      new_name(:body, :string, "New name for the item", required: true)
    end

    response(200, "OK", Schema.ref(:StorageItem))
    response(400, "Bad Request", Schema.ref(:Error))
    response(404, "Not Found", Schema.ref(:Error))
    response(409, "Conflict", Schema.ref(:Error))
  end

  @doc """
  Renames a storage item (file or folder).

  ## Route
  POST /api/v1/storage/items/:id/rename

  ## Parameters
  - id: Item UUID (path parameter)
  - new_name: New name for the item (body parameter)

  ## Examples
      POST /api/v1/storage/items/550e8400-e29b-41d4-a716-446655440000/rename
      {
        "new_name": "Renamed Document.pdf"
      }
  """
  def rename(conn, %{"id" => id, "new_name" => new_name}) do
    organisation_id = conn.assigns[:current_user].current_org_id

    case StorageItems.get_storage_item_by_org(id, organisation_id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Storage item not found"})

      storage_item ->
        case StorageItems.rename_storage_item(storage_item, new_name, organisation_id) do
          {:ok, updated_item} ->
            Logger.info("Storage item renamed", %{
              item_id: id,
              new_name: new_name,
              organisation_id: organisation_id
            })

            conn
            |> put_status(:ok)
            |> render("show.json", storage_item: updated_item)

          {:error, :invalid_name} ->
            conn
            |> put_status(:bad_request)
            |> json(%{error: "Invalid name. Names cannot contain forward slashes."})

          {:error, :duplicate_name} ->
            conn
            |> put_status(:conflict)
            |> json(%{error: "An item with this name already exists in this folder"})

          {:error, %Ecto.Changeset{} = changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{
              error: "Failed to rename item",
              details: Ecto.Changeset.traverse_errors(changeset, &translate_error/1)
            })
        end
    end
  end
end
