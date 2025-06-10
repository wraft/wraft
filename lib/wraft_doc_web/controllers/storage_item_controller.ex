defmodule WraftDocWeb.Api.V1.StorageItemController do
  use WraftDocWeb, :controller
  require Logger

  alias WraftDoc.Storage
  alias WraftDoc.Storage.StorageItem
  alias WraftDoc.Storage.StorageAsset
  alias WraftDoc.Storage.Repository
  import WraftDocWeb.ErrorHelpers

  action_fallback WraftDocWeb.FallbackController

  @doc """
  Lists storage items in the root folder or a specific folder.

  Query parameters:
  - parent_id: Optional parent folder ID to list contents of a specific folder
  - repository_id: Optional repository ID to filter by repository
  - limit: Number of items to return (1-1000, default: 100)
  - offset: Number of items to skip (default: 0)
  - sort_by: Sort field - "name", "created", "updated", "size", "type" (default: "created")
  - sort_order: Sort direction - "asc" or "desc" (default: "desc")

  If no parent_id is provided, returns root level items.
  If parent_id is provided, returns children of that folder.

  Sorting options:
  - "name": Alphabetical by name (folders first)
  - "created": By creation date (newest first by default)
  - "updated": By last modified date (newest first by default)
  - "size": By file size (folders first, then by size)
  - "type": By file type/extension (folders first)
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
    # Parse pagination parameters
    limit = parse_integer(params["limit"], 100, 1, 1000)
    offset = parse_integer(params["offset"], 0, 0, nil)

    # Parse sorting parameters
    sort_by = Map.get(params, "sort_by", "created")
    sort_order = Map.get(params, "sort_order", "desc")

    pagination_opts = [
      limit: limit,
      offset: offset,
      sort_by: sort_by,
      sort_order: sort_order
    ]

    result = case params do
      %{"parent_id" => parent_id} when parent_id != "" ->
        Logger.info("📁 Fetching contents of folder", %{parent_id: parent_id, organisation_id: organisation_id, sort_by: sort_by, sort_order: sort_order})
        # Validate that the folder exists and belongs to the organization
        case Storage.get_storage_item_by_org(parent_id, organisation_id) do
          %StorageItem{mime_type: "inode/directory"} = _folder ->
            Logger.info("✅ Folder found, listing contents", %{parent_id: parent_id})
            {:ok, Storage.list_storage_items_with_breadcrumbs(parent_id, organisation_id, pagination_opts)}
          %StorageItem{} ->
            Logger.warn("❌ Item exists but is not a directory", %{parent_id: parent_id})
            {:error, :not_a_directory}
          nil ->
            Logger.warn("❌ Folder not found", %{parent_id: parent_id, organisation_id: organisation_id})
            {:error, :folder_not_found}
        end

      %{"repository_id" => repository_id} when repository_id != "" ->
        parent_id = Map.get(params, "parent_id")
        Logger.info("🗄️ Fetching repository contents", %{repository_id: repository_id, parent_id: parent_id, organisation_id: organisation_id, sort_by: sort_by, sort_order: sort_order})
        # For repository filtering, we'll use the regular function but wrap the result
        items = Storage.list_repository_storage_items(repository_id, parent_id, organisation_id, pagination_opts)
        breadcrumbs = if parent_id do
          Storage.get_storage_item_breadcrumb_navigation(parent_id, organisation_id)
        else
          []
        end
        current_folder = if parent_id do
          case Storage.get_storage_item_by_org(parent_id, organisation_id) do
            %StorageItem{} = folder ->
              %{
                id: folder.id,
                name: get_folder_name(folder),
                is_folder: folder.mime_type == "inode/directory",
                path: folder.path,
                materialized_path: folder.materialized_path
              }
            nil -> nil
          end
        else
          nil
        end
        {:ok, %{items: items, breadcrumbs: breadcrumbs, current_folder: current_folder}}

      _ ->
        Logger.info("🏠 Fetching root level items", %{organisation_id: organisation_id, sort_by: sort_by, sort_order: sort_order})
        IO.inspect(organisation_id)
        # Default to root level items using our new function with breadcrumbs
        {:ok, Storage.list_storage_items_with_breadcrumbs(nil, organisation_id, pagination_opts)}
    end

    case result do
      {:error, :not_a_directory} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "The specified ID is not a directory"})

      {:error, :folder_not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Folder not found"})

      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: reason})

      {:ok, %{items: items, breadcrumbs: breadcrumbs, current_folder: current_folder}} ->
        Logger.info("Storage items listed", %{
          organisation_id: organisation_id,
          count: length(items),
          breadcrumbs_count: length(breadcrumbs),
          current_folder: current_folder,
          sort_by: sort_by,
          sort_order: sort_order,
          params: Map.take(params, ["parent_id", "repository_id", "limit", "offset", "sort_by", "sort_order"])
        })

        conn
        |> json(%{
          data: for(item <- items, do: storage_item_data(item)),
          breadcrumbs: breadcrumbs,
          current_folder: current_folder,
          meta: %{
            count: length(items),
            breadcrumbs_count: length(breadcrumbs),
            sort_by: sort_by,
            sort_order: sort_order,
            timestamp: DateTime.utc_now()
          }
        })
    end
  end

  @doc """
  Gets breadcrumb navigation for a storage item.
  """
  def breadcrumbs(conn, %{"id" => id}) do
    current_user = conn.assigns[:current_user]
    organisation_id = current_user.current_org_id

    with :ok <- validate_uuid_param(%{"id" => id}, "id") do
      breadcrumbs = Storage.get_storage_item_breadcrumb_navigation(id, organisation_id)

      conn
      |> json(%{
        data: breadcrumbs
      })
    else
      {:error, _field} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid UUID format for id"})
    end
  end

  @doc """
  Gets storage navigation data including current folder items and breadcrumb navigation.
  This combines the listing and breadcrumb functionality for convenience.
  """
  def navigation(conn, params) do
    current_user = conn.assigns[:current_user]
    organisation_id = current_user.current_org_id

    parent_id = Map.get(params, "parent_id")

    with :ok <- validate_uuid_param(params, "parent_id") do
      # Parse pagination parameters
      limit = parse_integer(params["limit"], 100, 1, 1000)
      offset = parse_integer(params["offset"], 0, 0, nil)
      pagination_opts = [limit: limit, offset: offset]

      navigation_data = Storage.get_storage_navigation_data(parent_id, organisation_id, pagination_opts)

      Logger.info("Storage navigation data retrieved", %{
        organisation_id: organisation_id,
        parent_id: parent_id,
        items_count: length(navigation_data.items),
        breadcrumbs_count: length(navigation_data.breadcrumbs)
      })

      conn
      |> json(%{
        data: %{
          items: for(item <- navigation_data.items, do: storage_item_data(item)),
          breadcrumbs: navigation_data.breadcrumbs
        },
        meta: %{
          count: length(navigation_data.items),
          timestamp: DateTime.utc_now()
        }
      })
    else
      {:error, _field} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid UUID format for parent_id"})
    end
  end

  def create(conn, %{"storage_item" => storage_item_params}) do
    with {:ok, %StorageItem{} = storage_item} <- Storage.create_storage_item(storage_item_params) do
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
        folder_params = folder_params
          |> Map.put("item_type", "folder")
          |> Map.put("mime_type", "inode/directory")
          |> Map.put("size", 0)
          |> Map.put("depth_level", folder_depth_level)
          |> Map.put("materialized_path",  folder_params["path"])
          |> Map.put("creator_id", current_user.id)
          |> Map.put("organisation_id", organisation_id)
          |> Map.put("repository_id", repository.id)

        # Create the folder in storage
        case Storage.create_storage_item(folder_params) do
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
        Logger.warn("No repositories found for organisation", %{organisation_id: organisation_id})

        conn
        |> put_status(:not_found)
        |> json(%{
          error: "No repository found",
          message: "No repository exists for this organisation"
        })
    end
  end

  def show(conn, %{"id" => id}) do
    current_user = conn.assigns[:current_user]
    organisation_id = current_user.current_org_id

    with :ok <- validate_uuid_param(%{"id" => id}, "id"),
         %StorageItem{} = storage_item <- Storage.get_storage_item_by_org(id, organisation_id) do

      # Get linked storage assets
      storage_assets = Storage.get_storage_assets_for_item(storage_item.id)

      conn
      |> json(%{
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

  def update(conn, %{"id" => id, "storage_item" => storage_item_params}) do
    storage_item = Storage.get_storage_item!(id)

    with {:ok, %StorageItem{} = storage_item} <- Storage.update_storage_item(storage_item, storage_item_params) do
      render(conn, :show, storage_item: storage_item)
    end
  end

  def delete(conn, %{"id" => id}) do
    current_user = conn.assigns[:current_user]
    organisation_id = current_user.current_org_id

    with :ok <- validate_uuid_param(%{"id" => id}, "id"),
         %StorageItem{} = storage_item <- Storage.get_storage_item_by_org(id, organisation_id),
         {:ok, _} <- Storage.delete_storage_item(storage_item) do
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

      {:error, changeset} ->
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
      nil -> :ok
      "" -> :ok
      value ->
        case Ecto.UUID.cast(value) do
          {:ok, _} -> :ok
          :error -> {:error, key}
        end
    end
  end

  # Helper function to extract a meaningful name from a storage item
  defp get_folder_name(%StorageItem{} = item) do
    cond do
      # Try display_name first
      not is_nil(item.display_name) and String.trim(item.display_name) != "" ->
        String.trim(item.display_name)

      # Try name next
      not is_nil(item.name) and String.trim(item.name) != "" ->
        String.trim(item.name)

      # Extract from path
      not is_nil(item.path) and String.trim(item.path) != "" ->
        extract_name_from_path(item.path)

      # Extract from materialized_path
      not is_nil(item.materialized_path) and String.trim(item.materialized_path) != "" ->
        extract_name_from_path(item.materialized_path)

      # Fallback
      true ->
        "Unnamed Folder"
    end
  end

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

  @doc """
  Renames a storage item (file or folder).
  """
  def rename(conn, %{"id" => id, "new_name" => new_name}, current_user, organisation_id) do
    case Storage.get_storage_item_by_org(id, organisation_id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Storage item not found"})

      storage_item ->
        case Storage.rename_storage_item(storage_item, new_name, organisation_id) do
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
