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
  alias WraftDoc.Storage.StorageAsset
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
            error: "Storage item not found",
            details: "The requested storage item does not exist"
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

    # Validate UUID format for parent_id and repository_id
    with :ok <- validate_uuid_param(params, "parent_id"),
         :ok <- validate_uuid_param(params, "repository_id") do
      process_index_request(conn, params, current_user, organisation_id)
    else
      {:error, field} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid UUID format for #{field}"})
    end
  end

  defp process_index_request(conn, params, _current_user, organisation_id) do
    pagination_opts = build_pagination_opts(params)

    result =
      cond do
        valid_parent_id?(params) ->
          handle_parent_flow(params, organisation_id, pagination_opts)

        valid_repository_id?(params) ->
          handle_repository_flow(params, organisation_id, pagination_opts)

        true ->
          handle_root_flow(organisation_id, pagination_opts)
      end

    respond_with_result(conn, result, params, organisation_id)
  end

  # BUILD PAGINATION OPTIONS
  defp build_pagination_opts(params) do
    limit = parse_integer(params["limit"], 100, 1, 1000)
    offset = parse_integer(params["offset"], 0, 0, nil)
    sort_by = Map.get(params, "sort_by", "created")
    sort_order = Map.get(params, "sort_order", "desc")

    [
      limit: limit,
      offset: offset,
      sort_by: sort_by,
      sort_order: sort_order
    ]
  end

  # CONDITION HELPERS
  defp valid_parent_id?(%{"parent_id" => parent_id}), do: parent_id != ""
  defp valid_parent_id?(_), do: false

  defp valid_repository_id?(%{"repository_id" => repository_id}), do: repository_id != ""
  defp valid_repository_id?(_), do: false

  # HANDLE FLOWS
  defp handle_parent_flow(params, organisation_id, pagination_opts) do
    parent_id = params["parent_id"]
    sort_by = pagination_opts[:sort_by]
    sort_order = pagination_opts[:sort_order]

    Logger.info("📁 Fetching contents of folder", %{
      parent_id: parent_id,
      organisation_id: organisation_id,
      sort_by: sort_by,
      sort_order: sort_order
    })

    case StorageItems.get_storage_item_by_org(parent_id, organisation_id) do
      %StorageItem{mime_type: "inode/directory"} ->
        Logger.info("✅ Folder found, listing contents", %{parent_id: parent_id})

        {:ok,
         StorageItems.list_storage_items_with_breadcrumbs(
           parent_id,
           organisation_id,
           pagination_opts
         )}

      %StorageItem{} ->
        Logger.warning("❌ Item exists but is not a directory", %{parent_id: parent_id})
        {:error, :not_a_directory}

      nil ->
        Logger.warning("❌ Folder not found", %{
          parent_id: parent_id,
          organisation_id: organisation_id
        })

        {:error, :folder_not_found}
    end
  end

  defp handle_repository_flow(params, organisation_id, pagination_opts) do
    repository_id = params["repository_id"]
    parent_id = Map.get(params, "parent_id")
    sort_by = pagination_opts[:sort_by]
    sort_order = pagination_opts[:sort_order]

    Logger.info("🗄️ Fetching repository contents", %{
      repository_id: repository_id,
      parent_id: parent_id,
      organisation_id: organisation_id,
      sort_by: sort_by,
      sort_order: sort_order
    })

    items =
      Storage.list_repository_storage_items(
        repository_id,
        parent_id,
        organisation_id,
        pagination_opts
      )

    breadcrumbs =
      if parent_id,
        do: StorageItems.get_storage_item_breadcrumb_navigation(parent_id, organisation_id),
        else: []

    current_folder =
      if parent_id do
        case StorageItems.get_storage_item_by_org(parent_id, organisation_id) do
          %StorageItem{} = folder ->
            %{
              id: folder.id,
              name: get_folder_name(folder),
              is_folder: folder.mime_type == "inode/directory",
              path: folder.path,
              materialized_path: folder.materialized_path
            }

          nil ->
            nil
        end
      else
        nil
      end

    {:ok, %{items: items, breadcrumbs: breadcrumbs, current_folder: current_folder}}
  end

  defp handle_root_flow(organisation_id, pagination_opts) do
    Logger.info("🏠 Fetching root level items", %{organisation_id: organisation_id})
    {:ok, StorageItems.list_storage_items_with_breadcrumbs(nil, organisation_id, pagination_opts)}
  end

  # BUILD RESPONSE
  defp respond_with_result(
         conn,
         {:ok, %{items: items, breadcrumbs: breadcrumbs, current_folder: current_folder}},
         params,
         organisation_id
       ) do
    log_success(organisation_id, items, breadcrumbs, current_folder, params)

    json(conn, %{
      data: Enum.map(items, &storage_item_data/1),
      breadcrumbs: breadcrumbs,
      current_folder: current_folder,
      meta: build_meta(items, breadcrumbs, params)
    })
  end

  defp respond_with_result(conn, {:error, :not_a_directory}, _params, _org) do
    conn |> put_status(:bad_request) |> json(%{error: "The specified ID is not a directory"})
  end

  defp respond_with_result(conn, {:error, :folder_not_found}, _params, _org) do
    conn |> put_status(:not_found) |> json(%{error: "Folder not found"})
  end

  defp log_success(organisation_id, items, breadcrumbs, current_folder, params) do
    Logger.info("Storage items listed", %{
      organisation_id: organisation_id,
      count: length(items),
      breadcrumbs_count: length(breadcrumbs),
      current_folder: current_folder,
      sort_by: Map.get(params, "sort_by"),
      sort_order: Map.get(params, "sort_order"),
      params:
        Map.take(params, [
          "parent_id",
          "repository_id",
          "limit",
          "offset",
          "sort_by",
          "sort_order"
        ])
    })
  end

  defp build_meta(items, breadcrumbs, params) do
    %{
      count: length(items),
      breadcrumbs_count: length(breadcrumbs),
      sort_by: Map.get(params, "sort_by"),
      sort_order: Map.get(params, "sort_order"),
      timestamp: DateTime.utc_now()
    }
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
    organisation_id = current_user.current_org_id

    case validate_uuid_param(%{"id" => id}, "id") do
      :ok ->
        breadcrumbs = StorageItems.get_storage_item_breadcrumb_navigation(id, organisation_id)

        json(conn, %{data: breadcrumbs})

      {:error, _field} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid UUID format for id"})
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
    organisation_id = current_user.current_org_id
    parent_id = Map.get(params, "parent_id")

    case validate_uuid_param(params, "parent_id") do
      :ok -> handle_navigation(conn, parent_id, organisation_id, params)
      {:error, _field} -> respond_invalid_uuid(conn)
    end
  end

  defp handle_navigation(conn, parent_id, organisation_id, params) do
    pagination_opts = build_pagination_opts(params)

    navigation_data =
      Storage.get_storage_navigation_data(parent_id, organisation_id, pagination_opts)

    log_navigation_retrieved(organisation_id, parent_id, navigation_data)

    response = build_navigation_response(navigation_data)

    json(conn, response)
  end

  # defp build_pagination_opts(params) do
  #   limit = parse_integer(params["limit"], 100, 1, 1000)
  #   offset = parse_integer(params["offset"], 0, 0, nil)
  #   [limit: limit, offset: offset]
  # end

  defp log_navigation_retrieved(organisation_id, parent_id, navigation_data) do
    Logger.info("Storage navigation data retrieved", %{
      organisation_id: organisation_id,
      parent_id: parent_id,
      items_count: length(navigation_data.items),
      breadcrumbs_count: length(navigation_data.breadcrumbs)
    })
  end

  defp build_navigation_response(navigation_data) do
    %{
      data: %{
        items: Enum.map(navigation_data.items, &storage_item_data/1),
        breadcrumbs: navigation_data.breadcrumbs
      },
      meta: %{
        count: length(navigation_data.items),
        timestamp: DateTime.utc_now()
      }
    }
  end

  defp respond_invalid_uuid(conn) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Invalid UUID format for parent_id"})
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

  def create(conn, %{"storage_item" => storage_item_params}) do
    with {:ok, %StorageItem{} = storage_item} <-
           StorageItems.create_storage_item(storage_item_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", "/api/storage_items/#{storage_item}")
      |> render(:show, storage_item: storage_item)
    end
  end

  @doc """
  Calculates the depth level of a storage item based on its path.

  ## Examples

      iex> calculate_depth_level("/Documents/Contracts/Q4/August")
      4

      iex> calculate_depth_level("/")
      0

      iex> calculate_depth_level("")
      0
  """
  def calculate_depth_level(path) when is_binary(path) do
    path
    |> String.trim("/")
    |> String.split("/")
    |> Enum.reject(&(&1 == ""))
    |> length()
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

    Logger.info("📁 Starting folder creation", %{
      user_id: current_user.id,
      organisation_id: organisation_id,
      folder_name: folder_params["name"],
      parent_id: folder_params["parent_id"]
    })

    folder_depth_level = calculate_depth_level(folder_params["path"])

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
            |> render(:show, storage_item: storage_item)

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

    with :ok <- validate_uuid_param(%{"id" => id}, "id"),
         %StorageItem{} = storage_item <-
           StorageItems.get_storage_item_by_org(id, organisation_id) do
      # Get linked storage assets
      storage_assets = StorageAssets.get_storage_assets_for_item(storage_item.id)

      json(conn, %{
        data: WraftDocWeb.Api.V1.StorageItemView.data(storage_item, storage_assets)
      })
    else
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Storage item not found"})

      {:error, :invalid_uuid} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid storage item ID format"})
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

    with :ok <- validate_uuid_param(%{"id" => id}, "id"),
         %StorageItem{} = storage_item <-
           StorageItems.get_storage_item_by_org(id, organisation_id),
         {:ok, _} <- StorageItems.delete_storage_item(storage_item) do
      conn
      |> put_status(:ok)
      |> json(%{
        message: "Storage item marked for deletion",
        id: id
      })
    else
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Storage item not found"})

      {:error, :invalid_uuid} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid storage item ID format"})

      {:error, _changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Failed to mark storage item for deletion"})
    end
  end

  # Helper function to format storage item data
  defp storage_item_data(%StorageItem{} = storage_item, storage_assets \\ []) do
    %{
      id: storage_item.id,
      name: storage_item.name,
      display_name: storage_item.display_name,
      item_type: storage_item.item_type,
      path: storage_item.path,
      mime_type: storage_item.mime_type,
      file_extension: storage_item.file_extension,
      size: storage_item.size,
      is_folder: storage_item.mime_type == "inode/directory",
      depth_level: storage_item.depth_level,
      materialized_path: storage_item.materialized_path,
      version_number: storage_item.version_number,
      is_current_version: storage_item.is_current_version,
      classification_level: storage_item.classification_level,
      content_extracted: storage_item.content_extracted,
      thumbnail_generated: storage_item.thumbnail_generated,
      download_count: storage_item.download_count,
      last_accessed_at: storage_item.last_accessed_at,
      metadata: storage_item.metadata,
      parent_id: storage_item.parent_id,
      repository_id: storage_item.repository_id,
      creator_id: storage_item.creator_id,
      organisation_id: storage_item.organisation_id,
      inserted_at: storage_item.inserted_at,
      updated_at: storage_item.updated_at,
      assets: Enum.map(storage_assets, &storage_asset_data/1)
    }
  end

  # Helper function to format storage asset data
  defp storage_asset_data(%StorageAsset{} = storage_asset) do
    %{
      id: storage_asset.id,
      filename: storage_asset.filename,
      storage_key: storage_asset.storage_key,
      storage_backend: storage_asset.storage_backend,
      file_size: storage_asset.file_size,
      mime_type: storage_asset.mime_type,
      processing_status: storage_asset.processing_status,
      upload_completed_at: storage_asset.upload_completed_at,
      checksum_sha256: storage_asset.checksum_sha256,
      thumbnail_path: storage_asset.thumbnail_path,
      preview_path: storage_asset.preview_path,
      inserted_at: storage_asset.inserted_at,
      updated_at: storage_asset.updated_at,
      url: WraftDocWeb.StorageAssetUploader.url({storage_asset.filename, storage_asset})
    }
  end

  # Helper function to parse integer parameters with validation
  defp parse_integer(value, default, min, max) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} when int >= min ->
        if max && int > max, do: max, else: int

      _ ->
        default
    end
  end

  defp parse_integer(_, default, _, _), do: default

  # Helper function to validate UUID parameters
  defp validate_uuid_param(params, key) do
    case Map.get(params, key) do
      nil ->
        :ok

      "" ->
        :ok

      value ->
        case Ecto.UUID.cast(value) do
          {:ok, _} -> :ok
          :error -> {:error, key}
        end
    end
  end

  # Helper function to extract a meaningful name from a storage item
  defp get_folder_name(%StorageItem{} = item) do
    item.display_name
    |> fallback(item.name)
    |> fallback(item.path && extract_name_from_path(item.path))
    |> fallback(item.materialized_path && extract_name_from_path(item.materialized_path))
    |> default_if_blank("Unnamed Folder")
  end

  defp fallback(nil, fallback), do: fallback
  defp fallback("", fallback), do: fallback
  defp fallback(value, _fallback), do: value

  defp default_if_blank(nil, default), do: default
  defp default_if_blank("", default), do: default
  defp default_if_blank(value, _default), do: value

  # Helper function to extract the last segment from a path
  defp extract_name_from_path(path) when is_binary(path) do
    path
    |> String.trim()
    |> String.trim_trailing("/")
    |> String.split("/")
    |> List.last()
    |> case do
      nil -> "Root"
      "" -> "Root"
      name -> name
    end
  end

  defp extract_name_from_path(_), do: "Unknown"

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
  def rename(conn, %{"id" => id, "new_name" => new_name}, _current_user, organisation_id) do
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
            |> render(:show, storage_item: updated_item)

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
