defmodule WraftDocWeb.Api.V1.StorageAssetsController do
  @moduledoc """
  API endpoints for managing storage assets (files and metadata).

  Provides operations for:
  - Listing and searching files/folders
  - Viewing item details
  - Getting navigation breadcrumbs
  - Retrieving storage statistics

  ## Key Routes
  - GET /api/v1/storage/assets - List items
  - GET /api/v1/storage/assets/search - Search items
  - GET /api/v1/storage/assets/:id - Get item details
  - GET /api/v1/storage/assets/:id/breadcrumbs - Get navigation path
  - GET /api/v1/storage/assets/stats - Get storage statistics
  """

  use WraftDocWeb, :controller
  use PhoenixSwagger
  require Logger

  alias WraftDoc.Storage
  alias WraftDoc.Storage.StorageItem
  alias WraftDoc.Storage.StorageItems

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
      BreadcrumbItem:
        swagger_schema do
          title("Breadcrumb Item")
          description("An item in the breadcrumb navigation path")

          properties do
            id(:string, "ID of the folder", format: "uuid")
            name(:string, "Name of the folder", required: true)
            display_name(:string, "Display name of the folder")
            is_folder(:boolean, "Whether this is a folder", default: true)
            path(:string, "Path to the folder")
          end

          example(%{
            id: "550e8400-e29b-41d4-a716-446655440001",
            name: "Documents",
            display_name: "My Documents",
            is_folder: true,
            path: "/Documents"
          })
        end,
      StorageStats:
        swagger_schema do
          title("Storage Statistics")
          description("Statistics for a folder or root directory")

          properties do
            total_items(:integer, "Total number of items")
            total_size(:integer, "Total size in bytes")
            file_count(:integer, "Number of files")
            folder_count(:integer, "Number of folders")
            last_updated(:string, "Last update timestamp", format: "ISO-8601")
          end

          example(%{
            total_items: 42,
            total_size: 10_485_760,
            file_count: 35,
            folder_count: 7,
            last_updated: "2023-01-15T10:30:00Z"
          })
        end,
      Error:
        swagger_schema do
          title("Error Response")
          description("Standard error format")

          properties do
            error(:string, "Error message", example: "Invalid folder ID")
            details(:string, "Additional details", example: "The specified folder does not exist")
            code(:string, "Error code", example: "not_found", required: false)
          end

          example(%{
            error: "Validation failed",
            details: "Search term must be at least 2 characters",
            code: "invalid_input"
          })
        end,
      StorageItemList:
        swagger_schema do
          title("Storage Item List")
          description("Paginated list of storage items with metadata")

          properties do
            data(:array, "List of storage items", items: Schema.ref(:StorageItem))

            meta(:object, "Pagination metadata",
              properties: %{
                total: %{type: :integer, example: 42},
                limit: %{type: :integer, example: 100},
                offset: %{type: :integer, example: 0}
              }
            )
          end

          example(%{
            data: [
              %{
                id: "550e8400-e29b-41d4-a716-446655440000",
                name: "contract.pdf",
                item_type: "file",
                size: 1024
              }
            ],
            meta: %{
              total: 42,
              limit: 100,
              offset: 0
            }
          })
        end,
      SearchResponse:
        swagger_schema do
          title("Search Response")
          description("Paginated search results")

          properties do
            data(:array, "Matching items", items: Schema.ref(:StorageItem))
            total(:integer, "Total number of matches")
            limit(:integer, "Number of items returned")
            offset(:integer, "Number of items skipped")
          end

          example(%{
            data: [
              %{
                id: "550e8400-e29b-41d4-a716-446655440000",
                name: "contract.pdf",
                item_type: "file",
                path: "/Contracts",
                mime_type: "application/pdf",
                size: 1024,
                is_folder: false
              }
            ],
            total: 5,
            limit: 1,
            offset: 0
          })
        end
    }
  end

  swagger_path :index do
    get("/storage/assets")
    summary("List storage items")

    description("""
    Lists files and folders with optional filtering.

    ### Filtering Options
    - By folder: `?folder_id=UUID`
    - By repository: `?repository_id=UUID`
    - By parent folder: `?parent_id=UUID` (when using repository_id)

    ### Pagination
    - limit: Items per page (1-1000, default: 100)
    - offset: Items to skip
    """)

    operation_id("listStorageItems")
    produces("application/json")
    tag("Storage Assets")

    parameters do
      folder_id(:query, :string, "Folder ID to list contents of", format: "uuid")
      repository_id(:query, :string, "Repository ID to filter by", format: "uuid")
      parent_id(:query, :string, "Parent ID when using repository_id", format: "uuid")

      limit(:query, :integer, "Number of items to return",
        default: 100,
        minimum: 1,
        maximum: 1000
      )

      offset(:query, :integer, "Number of items to skip", default: 0, minimum: 0)
    end

    response(200, "OK", Schema.ref(:StorageItemList))
    response(400, "Bad Request", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not Found", Schema.ref(:Error))
  end

  @doc """
  Lists storage items with filtering options.

  ## Route
  GET /api/v1/storage/assets

  ## Parameters
  - folder_id: Filter by folder UUID
  - repository_id: Filter by repository UUID
  - parent_id: Filter by parent folder (with repository_id)
  - limit: Pagination limit (default: 100)
  - offset: Pagination offset

  ## Examples
      # List root items
      GET /api/v1/storage/assets

      # List folder contents
      GET /api/v1/storage/assets?folder_id=550e8400-e29b-41d4-a716-446655440000

      # List repository contents
      GET /api/v1/storage/assets?repository_id=550e8400-e29b-41d4-a716-446655440001&parent_id=550e8400-e29b-41d4-a716-446655440002
  """

  def index(conn, params) do
    current_user = conn.assigns[:current_user]
    organisation_id = current_user.current_org_id

    # Validate UUID format for folder_id and repository_id
    with :ok <- validate_uuid_param(params, "folder_id"),
         :ok <- validate_uuid_param(params, "repository_id"),
         :ok <- validate_uuid_param(params, "parent_id") do
      process_index_request(conn, params, current_user, organisation_id)
    else
      {:error, field} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid UUID format for #{field}"})
    end
  end

  defp process_index_request(conn, params, _current_user, organisation_id) do
    pagination_opts = parse_pagination_opts(params)

    result = resolve_storage_items(params, organisation_id, pagination_opts)

    handle_storage_items_result(conn, result, params, organisation_id)
  end

  # Extract pagination parsing into its own function (helps Credo & readability)
  defp parse_pagination_opts(params) do
    limit = parse_integer(params["limit"], 100, 1, 1000)
    offset = parse_integer(params["offset"], 0, 0, nil)
    [limit: limit, offset: offset]
  end

  defp resolve_storage_items(%{"folder_id" => folder_id}, organisation_id, pagination_opts)
       when folder_id != "" do
    case StorageItems.get_storage_item_by_org(folder_id, organisation_id) do
      %StorageItem{mime_type: "inode/directory"} ->
        StorageItems.list_storage_items_by_parent(folder_id, organisation_id, pagination_opts)

      %StorageItem{} ->
        {:error, :not_a_directory}

      nil ->
        {:error, :folder_not_found}
    end
  end

  defp resolve_storage_items(
         %{"repository_id" => repository_id} = params,
         organisation_id,
         pagination_opts
       )
       when repository_id != "" do
    parent_id = Map.get(params, "parent_id")

    Storage.list_repository_storage_items(
      repository_id,
      parent_id,
      organisation_id,
      pagination_opts
    )
  end

  defp resolve_storage_items(_params, organisation_id, pagination_opts) do
    StorageItems.list_root_storage_items(organisation_id, pagination_opts)
  end

  # Handle results separately — very Credo-friendly
  defp handle_storage_items_result(conn, {:error, :not_a_directory}, _params, _org_id) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "The specified ID is not a directory"})
  end

  defp handle_storage_items_result(conn, {:error, :folder_not_found}, _params, _org_id) do
    conn
    |> put_status(:not_found)
    |> json(%{error: "Folder not found"})
  end

  defp handle_storage_items_result(conn, {:error, reason}, _params, _org_id) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: reason})
  end

  defp handle_storage_items_result(conn, items, params, organisation_id) do
    Logger.info("Storage assets listed", %{
      organisation_id: organisation_id,
      count: length(items),
      params: Map.take(params, ["folder_id", "repository_id", "parent_id", "limit", "offset"])
    })

    render(conn, :index, storage_items: items)
  end

  swagger_path :show do
    get("/storage/assets/{id}")
    summary("Get storage item details")
    description("Returns detailed information about a specific storage item")
    operation_id("getStorageItem")
    produces("application/json")
    tag("Storage Assets")

    parameters do
      id(:path, :string, "ID of the storage item", required: true, format: "uuid")
    end

    response(200, "OK", Schema.ref(:StorageItem))
    response(400, "Bad Request", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not Found", Schema.ref(:Error))
  end

  @doc """
  Shows details of a specific storage item.
  """
  def show(conn, %{"id" => id}) do
    current_user = conn.assigns[:current_user]
    organisation_id = current_user.current_org_id

    try do
      storage_item = StorageItems.get_storage_item_by_org!(id, organisation_id)
      render(conn, :show, storage_item: storage_item)
    rescue
      Ecto.NoResultsError ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Storage item not found"})
    end
  end

  swagger_path :breadcrumbs do
    get("/storage/assets/{id}/breadcrumbs")
    summary("Get breadcrumb navigation")
    description("Returns the breadcrumb path for a storage item")
    operation_id("getBreadcrumbs")
    produces("application/json")
    tag("Storage Assets")

    parameters do
      id(:path, :string, "ID of the storage item", required: true, format: "uuid")
    end

    response(200, "OK", %{
      type: :object,
      properties: %{
        data: %{
          type: :array,
          items: Schema.ref(:BreadcrumbItem),
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
        breadcrumbs = StorageItems.get_storage_item_breadcrumbs(id, organisation_id)

        json(conn, %{
          data: Enum.map(breadcrumbs, &breadcrumb_data/1)
        })

      {:error, _field} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid UUID format for id"})
    end
  end

  swagger_path :stats do
    get("/storage/assets/stats")
    summary("Get storage statistics")
    description("Returns statistics for a folder or root directory")
    operation_id("getStorageStats")
    produces("application/json")
    tag("Storage Assets")

    parameters do
      parent_id(:query, :string, "Parent folder ID", format: "uuid")
    end

    response(200, "OK", Schema.ref(:StorageStats))
    response(400, "Bad Request", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @doc """
  Gets statistics for a folder or root directory.
  """
  def stats(conn, params) do
    current_user = conn.assigns[:current_user]
    organisation_id = current_user.current_org_id
    parent_id = Map.get(params, "parent_id")

    case validate_uuid_param(params, "parent_id") do
      :ok -> handle_valid_stats(conn, parent_id, organisation_id)
      {:error, _field} -> handle_invalid_uuid(conn)
    end
  end

  defp handle_valid_stats(conn, parent_id, organisation_id) do
    stats = StorageItems.get_storage_item_stats(parent_id, organisation_id)

    json(conn, %{
      data: stats
    })
  end

  defp handle_invalid_uuid(conn) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Invalid UUID format for parent_id"})
  end

  swagger_path :search do
    get("/storage/assets/search")
    summary("Search storage items")

    description("""
    Full-text search across storage items.
    Requires at least 2 characters in search term.

    ### Examples
    - Search all: `?q=contract`
    - Filter by type: `?q=report&type=files`
    """)

    operation_id("searchStorageItems")
    produces("application/json")
    tag("Storage Assets")

    parameters do
      q(:query, :string, "Search term (min 2 characters)", required: true, minLength: 2)
      type(:query, :string, "Filter by item type", enum: ["files", "folders"])

      limit(:query, :integer, "Number of results to return",
        default: 50,
        minimum: 1,
        maximum: 100
      )

      offset(:query, :integer, "Number of results to skip", default: 0, minimum: 0)
    end

    response(200, "OK", Schema.ref(:StorageItemList))
    response(400, "Bad Request", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @doc """
  Searches storage items by name.

  ## Route
  GET /api/v1/storage/assets/search

  ## Parameters
  - q: Search term (required, min 2 chars)
  - type: Filter by type ("files" or "folders")
  - limit: Results per page (default: 50)
  - offset: Results to skip

  ## Examples
      # Basic search
      GET /api/v1/storage/assets/search?q=contract

      # Filtered search
      GET /api/v1/storage/assets/search?q=report&type=files&limit=20
  """
  def search(conn, params) do
    current_user = conn.assigns[:current_user]
    organisation_id = current_user.current_org_id

    search_term = Map.get(params, "q", "")

    if String.length(search_term) < 2 do
      conn
      |> put_status(:bad_request)
      |> json(%{error: "Search term must be at least 2 characters"})
    else
      # Parse pagination and filter parameters
      limit = parse_integer(params["limit"], 50, 1, 100)
      offset = parse_integer(params["offset"], 0, 0, nil)

      item_type_filter =
        case Map.get(params, "type") do
          "folders" -> :folders
          "files" -> :files
          _ -> nil
        end

      search_opts = [
        limit: limit,
        offset: offset,
        item_type: item_type_filter
      ]

      results = StorageItems.search_storage_items(search_term, organisation_id, search_opts)

      Logger.info("Storage items searched", %{
        organisation_id: organisation_id,
        search_term: search_term,
        count: length(results),
        params: Map.take(params, ["q", "type", "limit", "offset"])
      })

      render(conn, :index, storage_items: results)
    end
  end

  defp breadcrumb_data(storage_item) do
    %{
      id: storage_item.id,
      name: storage_item.name,
      display_name: storage_item.display_name,
      is_folder: storage_item.mime_type == "inode/directory",
      path: storage_item.path
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

      value when is_binary(value) ->
        case Ecto.UUID.cast(value) do
          {:ok, _} -> :ok
          :error -> {:error, key}
        end

      _ ->
        {:error, key}
    end
  end
end
