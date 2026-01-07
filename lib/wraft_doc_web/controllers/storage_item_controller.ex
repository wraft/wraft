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
  use OpenApiSpex.ControllerSpecs
  require Logger

  alias WraftDoc.Storages
  alias WraftDoc.Storages.Repository
  alias WraftDoc.Storages.StorageAssets
  alias WraftDoc.Storages.StorageItem
  alias WraftDoc.Storages.StorageItems
  alias WraftDocWeb.Schemas.Error
  alias WraftDocWeb.Schemas.StorageItem, as: StorageItemSchema

  import WraftDocWeb.ErrorHelpers

  plug WraftDocWeb.Plug.AddActionLog
  plug WraftDocWeb.Plug.FeatureFlagCheck, feature: :repository

  action_fallback(WraftDocWeb.FallbackController)

  tags(["Storage Items"])

  operation(:index,
    summary: "List storage items",
    description: """
    Lists storage items with pagination, sorting and filtering.

    ### Path Variations
    - `/storage/items` - Root level items
    - `/storage/items?parent_id=UUID` - Items within a specific folder
    - `/storage/items?repository_id=UUID` - Items within a specific repository

    ### Sorting
    Supported sort fields: name, created, updated, size, type
    """,
    operation_id: "listStorageItems",
    parameters: [
      parent_id: [
        in: :query,
        type: :string,
        description: "Parent folder ID to list contents (UUID)"
      ],
      repository_id: [in: :query, type: :string, description: "Repository ID to filter by (UUID)"],
      limit: [
        in: :query,
        type: :integer,
        description: "Number of items to return (default: 100, min: 1, max: 1000)"
      ],
      page: [in: :query, type: :integer, description: "Page number (default: 1)"],
      sort_by: [
        in: :query,
        type: :string,
        description: "Sort field (name, created, updated, size, type; default: created)"
      ],
      sort_order: [
        in: :query,
        type: :string,
        description: "Sort direction (asc, desc; default: desc)"
      ],
      search: [in: :query, type: :string, description: "Search query"]
    ],
    responses: [
      ok: {"OK", "application/json", StorageItemSchema.StorageItemsList},
      bad_request: {"Bad Request", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error},
      not_found: {"Not Found", "application/json", Error}
    ]
  )

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

    with :ok <- StorageItems.validate_uuid_param(params, "parent_id"),
         :ok <- StorageItems.validate_uuid_param(params, "repository_id"),
         {:ok, storage_items} <-
           StorageItems.process_index_request(current_user, params) do
      render(conn, "index.json", storage_items)
    end
  end

  operation(:breadcrumbs,
    summary: "Get breadcrumb navigation",
    description: "Gets breadcrumb navigation for a storage item",
    operation_id: "getStorageItemBreadcrumbs",
    parameters: [
      id: [in: :path, type: :string, description: "ID of the storage item (UUID)", required: true]
    ],
    responses: [
      ok:
        {"OK", "application/json",
         %OpenApiSpex.Schema{
           type: :object,
           properties: %{
             data: %OpenApiSpex.Schema{
               type: :array,
               items: StorageItemSchema.Breadcrumb,
               description: "Breadcrumb navigation items"
             }
           }
         }},
      bad_request: {"Bad Request", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error},
      not_found: {"Not Found", "application/json", Error}
    ]
  )

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

  operation(:navigation,
    summary: "Get navigation structure",
    description: """
    Returns combined folder contents and breadcrumbs for efficient navigation.

    ### Typical Flow
    1. Client loads root navigation
    2. User clicks into folder
    3. Client requests navigation for that folder
    """,
    operation_id: "getStorageNavigation",
    parameters: [
      parent_id: [in: :query, type: :string, description: "Parent folder ID (UUID)"],
      limit: [
        in: :query,
        type: :integer,
        description: "Number of items to return (default: 100, min: 1, max: 1000)"
      ],
      offset: [in: :query, type: :integer, description: "Number of items to skip (default: 0)"]
    ],
    responses: [
      ok: {"OK", "application/json", StorageItemSchema.NavigationData},
      bad_request: {"Bad Request", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

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

  operation(:create,
    summary: "Create a storage item",
    description: "Creates a new storage item (file or folder)",
    operation_id: "createStorageItem",
    request_body:
      {"Storage item creation parameters", "application/json",
       StorageItemSchema.StorageItemCreateParams},
    responses: [
      created: {"Created", "application/json", StorageItemSchema.StorageItem},
      bad_request: {"Bad Request", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error}
    ]
  )

  def create(conn, params) do
    with {:ok, %StorageItem{} = storage_item} <-
           StorageItems.create_storage_item(params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", "/api/storage_items/#{storage_item.id}")
      |> render("show.json", storage_item: storage_item)
    end
  end

  operation(:create_folder,
    summary: "Create a folder",
    description: """
    Creates a new folder in the specified location.

    ### Path Requirements
    - Path must be absolute (start with /)
    - Parent folders must exist
    """,
    operation_id: "createFolder",
    request_body:
      {"Folder creation parameters", "application/json", StorageItemSchema.FolderCreateParams},
    responses: [
      created: {"Created", "application/json", StorageItemSchema.StorageItem},
      bad_request: {"Bad Request", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error},
      not_found: {"Not Found", "application/json", Error},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error}
    ]
  )

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

    folder_depth_level = StorageItems.calculate_depth_level(folder_params["path"])

    case Storages.get_latest_repository(organisation_id) do
      %Repository{id: repository_id} = _repository ->
        folder_params =
          folder_params
          |> Map.put("item_type", "folder")
          |> Map.put("mime_type", "inode/directory")
          |> Map.put("size", 0)
          |> Map.put("depth_level", folder_depth_level)
          |> Map.put("materialized_path", folder_params["path"])
          |> Map.put("creator_id", current_user.id)
          |> Map.put("organisation_id", organisation_id)
          |> Map.put("repository_id", repository_id)

        case StorageItems.create_storage_item(folder_params) do
          {:ok, %StorageItem{} = storage_item} ->
            conn
            |> put_status(:created)
            |> put_resp_header("location", "/api/v1/storage/items/#{storage_item.id}")
            |> render("show.json", storage_item: storage_item)

          {:error, error} ->
            {:error, error}
        end

      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{
          error: "No repository found",
          message: "No repository exists for this organisation"
        })
    end
  end

  operation(:show,
    summary: "Get storage item details",
    description: "Returns detailed information about a specific storage item",
    operation_id: "getStorageItem",
    parameters: [
      id: [
        in: :path,
        type: :string,
        description: "ID of the storage item to fetch (UUID)",
        required: true
      ]
    ],
    responses: [
      ok: {"OK", "application/json", StorageItemSchema.StorageItem},
      bad_request: {"Bad Request", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error},
      not_found: {"Not Found", "application/json", Error}
    ]
  )

  def show(conn, %{"id" => id}) do
    current_user = conn.assigns[:current_user]
    organisation_id = current_user.current_org_id

    with :ok <- StorageItems.validate_uuid_param(%{"id" => id}, "id"),
         %StorageItem{} = storage_item <-
           StorageItems.get_storage_item_by_org(id, organisation_id) do
      storage_assets = StorageAssets.get_storage_assets_for_item(storage_item.id)

      render(conn, "storage_item.json",
        storage_item: storage_item,
        storage_asset: storage_assets
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

  operation(:update,
    summary: "Update storage item",
    description: "Updates an existing storage item",
    operation_id: "updateStorageItem",
    parameters: [
      id: [
        in: :path,
        type: :string,
        description: "ID of the storage item to update (UUID)",
        required: true
      ]
    ],
    request_body:
      {"Storage item update parameters", "application/json",
       StorageItemSchema.StorageItemUpdateParams},
    responses: [
      ok: {"OK", "application/json", StorageItemSchema.StorageItem},
      bad_request: {"Bad Request", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error},
      not_found: {"Not Found", "application/json", Error},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error}
    ]
  )

  def update(conn, %{"id" => id, "storage_item" => storage_item_params}) do
    storage_item = StorageItems.get_storage_item!(id)

    with {:ok, %StorageItem{} = storage_item} <-
           StorageItems.update_storage_item(storage_item, storage_item_params) do
      render(conn, :show, storage_item: storage_item)
    end
  end

  operation(:delete,
    summary: "Delete storage item",
    description: "Marks a storage item for deletion",
    operation_id: "deleteStorageItem",
    parameters: [
      id: [
        in: :path,
        type: :string,
        description: "ID of the storage item to delete (UUID)",
        required: true
      ]
    ],
    responses: [
      ok: {"OK", "application/json", StorageItemSchema.DeleteStorageItemResponse},
      bad_request: {"Bad Request", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error},
      not_found: {"Not Found", "application/json", Error},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error}
    ]
  )

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

  operation(:rename,
    summary: "Rename a storage item",
    description: """
    Renames a file or folder while maintaining all other properties.

    ### Restrictions
    - Cannot rename to existing name in same folder
    - Cannot include path separators (/)
    """,
    operation_id: "renameStorageItem",
    parameters: [
      id: [
        in: :path,
        type: :string,
        description: "ID of the item to rename (UUID)",
        required: true
      ]
    ],
    request_body: {"New name for the item", "application/json", StorageItemSchema.RenameParams},
    responses: [
      ok: {"OK", "application/json", StorageItemSchema.StorageItem},
      bad_request: {"Bad Request", "application/json", Error},
      not_found: {"Not Found", "application/json", Error},
      conflict: {"Conflict", "application/json", Error}
    ]
  )

  @doc """
  Renames a storage item (file or folder).

  ## Route
  PUT /api/v1/storage/items/:id/rename

  ## Parameters
  - id: Item UUID (path parameter)
  - new_name: New name for the item (body parameter)

  ## Examples
      PUT /api/v1/storage/items/550e8400-e29b-41d4-a716-446655440000/rename
      {
        "new_name": "Renamed Document.pdf"
      }
  """
  def rename(conn, %{"storage_item_id" => id, "new_name" => new_name}) do
    organisation_id = conn.assigns[:current_user].current_org_id

    case StorageItems.get_storage_item_by_org(id, organisation_id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Storage item not found"})

      storage_item ->
        case StorageItems.rename_storage_item(storage_item, new_name, organisation_id) do
          {:ok, updated_item} ->
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
