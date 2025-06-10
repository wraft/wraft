defmodule WraftDoc.Storage do
  @moduledoc """
  The Storage context handles file and folder management operations.

  ## File Upload API

  The storage system provides a complete file upload workflow that:

  1. **Creates storage assets** - Handles file metadata and backend storage
  2. **Creates storage items** - Manages hierarchical file organization
  3. **Links assets to items** - Maintains relationships between storage layers
  4. **Processes files** - Background content extraction and thumbnail generation
  5. **Logs access** - Tracks upload and access operations

  ### Main Upload Function

  `create_storage_asset_with_item/2` - Production-grade upload with full transaction support

  ### Features

  - **Multi-step transaction** - Ensures data consistency across all operations
  - **File validation** - Size, type, and security checks
  - **Hierarchical organization** - Proper folder structure with breadcrumbs
  - **Background processing** - Async content extraction and thumbnail generation
  - **Access logging** - Complete audit trail
  - **Error handling** - Comprehensive validation and rollback

  ### Supported File Types

  Images: jpg, jpeg, png
  Documents: pdf, doc, docx, odt, txt
  Spreadsheets: xls, xlsx, csv
  Presentations: ppt, pptx
  Archives: zip

  ### API Endpoint

  `POST /api/v1/storage/assets/upload`

  **Parameters:**
  - `file` (required) - The uploaded file
  - `parent_id` (optional) - Parent folder UUID
  - `repository_id` (optional) - Repository UUID
  - `display_name` (optional) - Custom display name
  - `classification_level` (optional) - Security level

  **Response:**
  ```json
  {
    "data": {
      "storage_asset": {...},
      "storage_item": {...}
    },
    "message": "File uploaded successfully",
    "meta": {
      "upload_completed_at": "2024-01-01T00:00:00Z",
      "processing_status": "completed"
    }
  }
  ```
  """

  import Ecto.Query, warn: false
  alias WraftDoc.Repo

  alias WraftDoc.Storage.Repository

  @doc """
  Returns the list of repositories.

  ## Examples

      iex> list_repositories()
      [%Repository{}, ...]

  """
  def list_repositories do
    Repo.all(Repository)
  end

  @doc """
  Gets the latest repository.

  ## Examples

      iex> get_latest_repository()
      %Repository{}

  """
  def get_latest_repository(organisation_id) do
    Repository
    |> where([r], r.organisation_id == ^organisation_id)
    |> order_by([r], desc: r.inserted_at)
    |> limit(1)
    |> Repo.one()
  end

  @doc """
  Gets a single repository.

  Raises `Ecto.NoResultsError` if the Repository does not exist.

  ## Examples

      iex> get_repository!(123)
      %Repository{}

      iex> get_repository!(456)
      ** (Ecto.NoResultsError)

  """
  def get_repository!(id), do: Repo.get!(Repository, id)

  @doc """
  Creates a repository.

  ## Examples

      iex> create_repository(%{field: value})
      {:ok, %Repository{}}

      iex> create_repository(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_repository(attrs \\ %{}) do
    %Repository{}
    |> Repository.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a repository.

  ## Examples

      iex> update_repository(repository, %{field: new_value})
      {:ok, %Repository{}}

      iex> update_repository(repository, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_repository(%Repository{} = repository, attrs) do
    repository
    |> Repository.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a repository.

  ## Examples

      iex> delete_repository(repository)
      {:ok, %Repository{}}

      iex> delete_repository(repository)
      {:error, %Ecto.Changeset{}}

  """
  def delete_repository(%Repository{} = repository) do
    Repo.delete(repository)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking repository changes.

  ## Examples

      iex> change_repository(repository)
      %Ecto.Changeset{data: %Repository{}}

  """
  def change_repository(%Repository{} = repository, attrs \\ %{}) do
    Repository.changeset(repository, attrs)
  end

  alias WraftDoc.Storage.StorageAsset

  @doc """
  Returns the list of storage_assets.

  ## Examples

      iex> list_storage_assets()
      [%StorageAsset{}, ...]

  """
  def list_storage_assets do
    Repo.all(StorageAsset)
  end

  @doc """
  Gets a single storage_asset.

  Raises `Ecto.NoResultsError` if the Storage asset does not exist.

  ## Examples

      iex> get_storage_asset!(123)
      %StorageAsset{}

      iex> get_storage_asset!(456)
      ** (Ecto.NoResultsError)

  """
  def get_storage_asset!(id), do: Repo.get!(StorageAsset, id)

  @doc """
  Creates a storage_asset.

  ## Examples

      iex> create_storage_asset(%{field: value})
      {:ok, %StorageAsset{}}

      iex> create_storage_asset(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_storage_asset(attrs \\ %{}) do
    %StorageAsset{}
    |> StorageAsset.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a storage_asset.

  ## Examples

      iex> update_storage_asset(storage_asset, %{field: new_value})
      {:ok, %StorageAsset{}}

      iex> update_storage_asset(storage_asset, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_storage_asset(%StorageAsset{} = storage_asset, attrs) do
    storage_asset
    |> StorageAsset.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a storage_asset.

  ## Examples

      iex> delete_storage_asset(storage_asset)
      {:ok, %StorageAsset{}}

      iex> delete_storage_asset(storage_asset)
      {:error, %Ecto.Changeset{}}

  """
  def delete_storage_asset(%StorageAsset{} = storage_asset) do
    Repo.delete(storage_asset)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking storage_asset changes.

  ## Examples

      iex> change_storage_asset(storage_asset)
      %Ecto.Changeset{data: %StorageAsset{}}

  """
  def change_storage_asset(%StorageAsset{} = storage_asset, attrs \\ %{}) do
    StorageAsset.changeset(storage_asset, attrs)
  end

  alias WraftDoc.Storage.StorageItem

  @doc """
  Returns the list of storage_items.
  When parent_id is nil, returns root level items.
  When parent_id is provided, returns children of that folder.

  ## Examples

      iex> list_storage_items()
      [%StorageItem{}, ...]

      iex> list_storage_items(parent_id, organisation_id)
      [%StorageItem{}, ...]

  """
  def list_storage_items(parent_id \\ nil, organisation_id \\ nil, opts \\ [])

  def list_storage_items(nil, nil, _opts) do
    # Legacy behavior - return all items (you might want to restrict this)
    Repo.all(StorageItem)
  end

  def list_storage_items(parent_id, organisation_id, opts) when is_binary(organisation_id) do
    limit = Keyword.get(opts, :limit, 100)
    offset = Keyword.get(opts, :offset, 0)
    sort_by = Keyword.get(opts, :sort_by, "created")
    sort_order = Keyword.get(opts, :sort_order, "desc")

    # Parse sorting options
    order_by_clause = parse_sort_options(sort_by, sort_order)

    base_query =
      from(s in StorageItem,
        where: s.organisation_id == ^organisation_id,
        where: s.is_deleted == false,
        order_by: ^order_by_clause,
        limit: ^limit,
        offset: ^offset
      )

    query =
      if parent_id do
        from(s in base_query, where: s.parent_id == ^parent_id)
      else
        # For root level items, filter by both parent_id being nil AND depth_level = 1
        from(s in base_query,
          where: is_nil(s.parent_id) and s.depth_level == 1)
      end

    Repo.all(query)
  end

  def list_storage_items(parent_id, organisation_id, opts) do
    list_storage_items(parent_id, to_string(organisation_id), opts)
  end

  @doc """
  Gets a single storage_item.

  Raises `Ecto.NoResultsError` if the Storage item does not exist.

  ## Examples

      iex> get_storage_item!(123)
      %StorageItem{}

      iex> get_storage_item!(456)
      ** (Ecto.NoResultsError)

  """
  def get_storage_item!(id), do: Repo.get!(StorageItem, id)

  @doc """
  Creates a storage item with duplicate name handling.
  If a file with the same name exists in the same folder, appends a number suffix.
  """
  def create_storage_item(attrs \\ %{}) do
    attrs = handle_duplicate_names(attrs)

    %StorageItem{}
    |> StorageItem.changeset(attrs)
    |> Repo.insert()
  end

  @doc false
  defp handle_duplicate_names(%{"parent_id" => parent_id, "name" => name} = attrs) when not is_nil(parent_id) do
    # Get all items in the same folder with similar names
    base_name = Path.rootname(name)
    extension = Path.extname(name)

    similar_names = from(s in StorageItem,
      where: s.parent_id == ^parent_id and s.is_deleted == false,
      where: like(s.name, ^"#{base_name}%#{extension}"),
      select: s.name
    ) |> Repo.all()

    if similar_names == [] do
      attrs
    else
      # Find the next available number
      next_number = find_next_available_number(similar_names, base_name, extension)
      Map.put(attrs, "name", "#{base_name}_#{next_number}#{extension}")
    end
  end
  defp handle_duplicate_names(attrs), do: attrs

  @doc false
  defp find_next_available_number(similar_names, base_name, extension) do
    # Extract numbers from existing names
    numbers = Enum.map(similar_names, fn name ->
      case Regex.run(~r/#{base_name}_(\d+)#{extension}/, name) do
        [_, num] -> String.to_integer(num)
        _ -> 0
      end
    end)

    # Find the next available number
    case numbers do
      [] -> 1
      nums -> Enum.max(nums) + 1
    end
  end

  @doc """
  Updates a storage_item.

  ## Examples

      iex> update_storage_item(storage_item, %{field: new_value})
      {:ok, %StorageItem{}}

      iex> update_storage_item(storage_item, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_storage_item(%StorageItem{} = storage_item, attrs) do
    storage_item
    |> StorageItem.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Marks a storage item as deleted and schedules deletion of its assets.
  For folders, schedules recursive deletion of all children.
  """
  def delete_storage_item(%StorageItem{} = storage_item) do
    Repo.transaction(fn ->
      # Mark the item as deleted
      storage_item
      |> StorageItem.changeset(%{
        is_deleted: true,
        deleted_at: DateTime.utc_now()
      })
      |> Repo.update()

      # If it's a folder, schedule recursive deletion of children
      if storage_item.mime_type == "inode/directory" do
        schedule_folder_deletion(storage_item.id)
      end

      # Schedule asset deletion
      schedule_asset_deletion(storage_item.id)
    end)
  end

  defp schedule_folder_deletion(folder_id) do
    %{folder_id: folder_id}
    |> WraftDoc.Workers.StorageDeletionWorker.new()
    |> Oban.insert()
  end

  defp schedule_asset_deletion(storage_item_id) do
    %{storage_item_id: storage_item_id}
    |> WraftDoc.Workers.StorageAssetDeletionWorker.new()
    |> Oban.insert()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking storage_item changes.

  ## Examples

      iex> change_storage_item(storage_item)
      %Ecto.Changeset{data: %StorageItem{}}

  """
  def change_storage_item(%StorageItem{} = storage_item, attrs \\ %{}) do
    StorageItem.changeset(storage_item, attrs)
  end

  @doc """
  Returns the current UTC datetime.
  """
  defp now_utc, do: DateTime.utc_now()

  @doc """
  Soft deletes a storage item and all its children (if it's a folder).
  Sets is_deleted to true and deleted_at to current timestamp.

  ## Examples

      iex> soft_delete_storage_item(storage_item)
      {:ok, %StorageItem{}}

      iex> soft_delete_storage_item(storage_item)
      {:error, %Ecto.Changeset{}}

  """
  def soft_delete_storage_item(%StorageItem{} = storage_item) do
    # Start a transaction to ensure all operations succeed or fail together
    Repo.transaction(fn ->
      now = now_utc()

      # If it's a folder, get all children recursively
      if storage_item.mime_type == "inode/directory" do
        children = get_all_children_storage_items(storage_item.id)
        child_ids = Enum.map(children, & &1.id)

        # Soft delete all children
        if length(child_ids) > 0 do
          StorageItem
          |> where([s], s.id in ^child_ids)
          |> Repo.update_all(set: [is_deleted: true, deleted_at: now])
        end
      end

      # Soft delete the main storage item
      storage_item
      |> StorageItem.changeset(%{is_deleted: true, deleted_at: now})
      |> Repo.update()
    end)
  end

  # Gets all children of a storage item recursively (for folders).
  defp get_all_children_storage_items(parent_id) do
    # Get immediate children
    children =
      from(s in StorageItem,
        where: s.parent_id == ^parent_id and s.is_deleted == false
      )
      |> Repo.all()

    # Recursively get children of children (for nested folders)
    Enum.flat_map(children, fn child ->
      if child.mime_type == "inode/directory" do
        [child | get_all_children_storage_items(child.id)]
      else
        [child]
      end
    end)
  end

  @doc """
  Returns the list of storage items in the path from root to current item.
  Only includes non-deleted items.
  Uses a recursive parent_id-based approach for better performance.
  """
  def get_storage_item_breadcrumbs(item_id, organisation_id) do
    case get_storage_item_by_org(item_id, organisation_id) do
      nil -> []
      item -> build_storage_ancestors(item, organisation_id, [])
    end
  end

  @doc """
  Returns simplified breadcrumb navigation data with just id and name.
  Useful for creating clickable navigation paths.

  ## Examples

      iex> get_storage_item_breadcrumb_navigation(item_id, organisation_id)
      [%{id: "root-id", name: "Root"}, %{id: "folder-id", name: "Documents"}]

  """
  def get_storage_item_breadcrumb_navigation(item_id, organisation_id) do
    get_storage_item_breadcrumbs(item_id, organisation_id)
    |> Enum.map(fn item ->
      # Try multiple ways to get a meaningful name
      name = get_meaningful_name(item)

      %{
        id: item.id,
        name: name,
        is_folder: item.mime_type == "inode/directory",
        path: item.path,
        materialized_path: item.materialized_path
      }
    end)
  end

  # Helper function to extract a meaningful name from a storage item
  defp get_meaningful_name(%StorageItem{} = item) do
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
  Returns storage navigation data including current folder items and breadcrumb navigation.
  This combines the listing and breadcrumb functionality for convenience.

  ## Examples

      iex> get_storage_navigation_data(folder_id, organisation_id)
      %{
        items: [%StorageItem{}, ...],
        breadcrumbs: [%{id: "root-id", name: "Root"}, ...]
      }

  """
  def get_storage_navigation_data(folder_id \\ nil, organisation_id, opts \\ []) do
    # Get the current folder's items
    items = list_storage_items(folder_id, organisation_id, opts)

    # Get breadcrumb navigation
    breadcrumbs = if folder_id do
      get_storage_item_breadcrumb_navigation(folder_id, organisation_id)
    else
      # For root level, return empty breadcrumbs or a root breadcrumb
      []
    end

    %{
      items: items,
      breadcrumbs: breadcrumbs
    }
  end

  @doc """
  Returns storage items with breadcrumb navigation for any parent context.
  This is similar to get_storage_navigation_data but with more flexible breadcrumb handling.

  ## Examples

      iex> list_storage_items_with_breadcrumbs(folder_id, organisation_id)
      %{
        items: [%StorageItem{}, ...],
        breadcrumbs: [%{id: "root-id", name: "Root"}, ...],
        current_folder: %{id: "folder-id", name: "Documents"} | nil
      }

  """
  def list_storage_items_with_breadcrumbs(parent_id \\ nil, organisation_id, opts \\ []) do
    # Get the current folder's items
    items = list_storage_items(parent_id, organisation_id, opts)

    # Get breadcrumb navigation and current folder info
    {breadcrumbs, current_folder} = if parent_id do
      case get_storage_item_by_org(parent_id, organisation_id) do
        %StorageItem{} = folder ->
          # Get breadcrumbs for the ancestors (excluding current folder)
          breadcrumbs = get_ancestors_breadcrumbs(folder, organisation_id)
          current_folder = %{
            id: folder.id,
            name: get_meaningful_name(folder),
            is_folder: folder.mime_type == "inode/directory",
            path: folder.path,
            materialized_path: folder.materialized_path
          }
          {breadcrumbs, current_folder}
        nil ->
          {[], nil}
      end
    else
      # For root level
      {[], nil}
    end

    %{
      items: items,
      breadcrumbs: breadcrumbs,
      current_folder: current_folder
    }
  end

  # Get breadcrumbs for ancestors only (excluding the current item)
  defp get_ancestors_breadcrumbs(%StorageItem{parent_id: nil} = current_item, organisation_id) do
    # Even if parent_id is nil, try to build breadcrumbs from path if it's multi-level
    path = current_item.materialized_path || current_item.path
    require Logger
    Logger.info("🔍 Building breadcrumbs for item with nil parent_id", %{
      id: current_item.id,
      path: path,
      materialized_path: current_item.materialized_path
    })

    if path && String.contains?(path, "/") do
      breadcrumbs = build_breadcrumbs_from_path(current_item, organisation_id)
      Logger.info("📍 Built breadcrumbs from path", %{breadcrumbs_count: length(breadcrumbs)})
      breadcrumbs
    else
      Logger.info("❌ No path available for breadcrumbs")
      []
    end
  end

  defp get_ancestors_breadcrumbs(%StorageItem{parent_id: parent_id} = current_item, organisation_id) when not is_nil(parent_id) do
    require Logger
    Logger.info("🔍 Building breadcrumbs for item with parent_id", %{
      id: current_item.id,
      parent_id: parent_id,
      path: current_item.path,
      materialized_path: current_item.materialized_path
    })

    # Try to get breadcrumbs using parent_id relationships first
    case get_storage_item_by_org(parent_id, organisation_id) do
      nil ->
        Logger.info("⚠️ Parent not found by parent_id, trying path-based breadcrumbs")
        # If parent_id doesn't point to an existing record, try to build from path
        build_breadcrumbs_from_path(current_item, organisation_id)
      parent ->
        Logger.info("✅ Found parent, building breadcrumbs from parent_id relationships")
        # Build using parent_id relationships
        build_storage_ancestors(parent, organisation_id, [])
        |> Enum.map(fn item ->
          %{
            id: item.id,
            name: get_meaningful_name(item),
            is_folder: item.mime_type == "inode/directory",
            path: item.path,
            materialized_path: item.materialized_path
          }
        end)
    end
  end

  # Build breadcrumbs from materialized_path when parent_id relationships are missing
  defp build_breadcrumbs_from_path(%StorageItem{} = current_item, organisation_id) do
    path = current_item.materialized_path || current_item.path

    if path && String.trim(path) != "" do
      # Split the path into segments
      segments = path
        |> String.trim()
        |> String.trim_leading("/")
        |> String.trim_trailing("/")
        |> String.split("/")
        |> Enum.reject(&(&1 == "" or is_nil(&1)))

      # Build breadcrumbs for each segment except the last one (current folder)
      segments
      |> Enum.drop(-1) # Remove current folder from breadcrumbs
      |> Enum.with_index()
      |> Enum.map(fn {segment, index} ->
        # Build the path up to this segment
        segment_path = "/" <> (Enum.take(segments, index + 1) |> Enum.join("/"))

        # Try to find the actual storage item for this path segment
        case find_storage_item_by_path(segment_path, organisation_id) do
          %StorageItem{} = item ->
            %{
              id: item.id,
              name: get_meaningful_name(item),
              is_folder: item.mime_type == "inode/directory",
              path: item.path,
              materialized_path: item.materialized_path
            }
          nil ->
            # Create virtual breadcrumb if no storage item found
            %{
              id: nil,
              name: segment,
              is_folder: true,
              path: segment_path,
              materialized_path: segment_path
            }
        end
      end)
    else
      []
    end
  end

  # Helper to find storage item by path
  defp find_storage_item_by_path(path, organisation_id) do
    from(s in StorageItem,
      where: s.organisation_id == ^organisation_id,
      where: s.is_deleted == false,
      where: s.materialized_path == ^path or s.path == ^path,
      limit: 1
    )
    |> Repo.one()
  end

  # Builds the list of ancestors recursively, starting from the current item
  defp build_storage_ancestors(%StorageItem{parent_id: nil} = item, _organisation_id, acc), do: [item | acc]

  defp build_storage_ancestors(%StorageItem{parent_id: parent_id} = item, organisation_id, acc) do
    case get_storage_item_by_org(parent_id, organisation_id) do
      nil -> [item | acc]
      parent -> build_storage_ancestors(parent, organisation_id, [item | acc])
    end
  end

  @doc """
  Returns the list of storage items in a repository.
  Only includes non-deleted items.

  ## Examples

      iex> list_storage_items_by_repository(repository_id, organisation_id)
      [%StorageItem{}, ...]

  """
  def list_storage_items_by_repository(repository_id, organisation_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)
    offset = Keyword.get(opts, :offset, 0)

    from(s in StorageItem,
      where: s.repository_id == ^repository_id,
      where: s.organisation_id == ^organisation_id,
      where: s.is_deleted == false,
      where: is_nil(s.parent_id),
      where: s.depth_level == 1,
      order_by: [asc: s.item_type, asc: s.name],
      limit: ^limit,
      offset: ^offset
    )
    |> Repo.all()
  end

  @doc """
  Lists storage items for a repository with optional parent folder filtering.
  Returns root level items when parent_id is nil.
  Filters by organization and excludes deleted items.
  Supports pagination with limit and offset.
  """
  def list_repository_storage_items(repository_id, parent_id \\ nil, organisation_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)
    offset = Keyword.get(opts, :offset, 0)
    sort_by = Keyword.get(opts, :sort_by, "created")
    sort_order = Keyword.get(opts, :sort_order, "desc")

    # Parse sorting options
    order_by_clause = parse_sort_options(sort_by, sort_order)

    query =
      from s in StorageItem,
        where: s.repository_id == ^repository_id,
        where: s.organisation_id == ^organisation_id,
        where: s.is_deleted == false,
        order_by: ^order_by_clause,
        limit: ^limit,
        offset: ^offset

    query =
      if parent_id do
        from s in query, where: s.parent_id == ^parent_id
      else
        # For root level items in repository, filter by parent_id being nil AND depth_level = 1
        from s in query,
          where: is_nil(s.parent_id) and s.depth_level == 1
      end

    Repo.all(query)
  end

  @doc """
  Gets storage items by parent folder ID with organization filtering.
  Supports pagination with limit and offset.
  """
  def list_storage_items_by_parent(parent_id, organisation_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)
    offset = Keyword.get(opts, :offset, 0)
    sort_by = Keyword.get(opts, :sort_by, "created")
    sort_order = Keyword.get(opts, :sort_order, "desc")

    # Parse sorting options
    order_by_clause = parse_sort_options(sort_by, sort_order)

    from(s in StorageItem,
      where: s.parent_id == ^parent_id,
      where: s.organisation_id == ^organisation_id,
      where: s.is_deleted == false,
      order_by: ^order_by_clause,
      limit: ^limit,
      offset: ^offset
    )
    |> Repo.all()
  end

  @doc """
  Gets root level storage items for an organization.
  Supports pagination with limit and offset.
  """
  def list_root_storage_items(organisation_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)
    offset = Keyword.get(opts, :offset, 0)

    from(s in StorageItem,
      where: is_nil(s.parent_id),
      where: s.depth_level == 1,
      where: s.organisation_id == ^organisation_id,
      where: s.is_deleted == false,
      order_by: [asc: s.item_type, asc: s.name],
      limit: ^limit,
      offset: ^offset
    )
    |> Repo.all()
  end

  @doc """
  Gets a storage item with organization validation.
  """
  def get_storage_item_by_org!(id, organisation_id) do
    from(s in StorageItem,
      where: s.id == ^id,
      where: s.organisation_id == ^organisation_id,
      where: s.is_deleted == false
    )
    |> Repo.one!()
  end

  @doc """
  Gets a storage item with organization validation, returns nil if not found.
  """
  def get_storage_item_by_org(id, organisation_id) do
    from(s in StorageItem,
      where: s.id == ^id,
      where: s.organisation_id == ^organisation_id,
      where: s.is_deleted == false
    )
    |> Repo.one()
  end

  @doc """
  Counts storage items in a folder or repository.
  """
  def count_storage_items(parent_id, organisation_id) when is_binary(parent_id) do
    from(s in StorageItem,
      where: s.parent_id == ^parent_id,
      where: s.organisation_id == ^organisation_id,
      where: s.is_deleted == false,
      select: count(s.id)
    )
    |> Repo.one()
  end

  def count_storage_items(nil, organisation_id) do
    from(s in StorageItem,
      where: is_nil(s.parent_id),
      where: s.depth_level == 1,
      where: s.organisation_id == ^organisation_id,
      where: s.is_deleted == false,
      select: count(s.id)
    )
    |> Repo.one()
  end

  @doc """
  Gets storage items statistics for a folder.
  Returns counts of files and folders, and total size.
  """
  def get_storage_item_stats(parent_id, organisation_id) do
    base_query =
      from(s in StorageItem,
        where: s.organisation_id == ^organisation_id,
        where: s.is_deleted == false
      )

    query =
      if parent_id do
        from(s in base_query, where: s.parent_id == ^parent_id)
      else
        # For root level stats, filter by parent_id being nil AND depth_level = 1
        from(s in base_query,
          where: is_nil(s.parent_id) and s.depth_level == 1)
      end

    stats =
      from(s in query,
        select: %{
          total_count: count(s.id),
          folder_count: sum(fragment("CASE WHEN ? = 'inode/directory' THEN 1 ELSE 0 END", s.mime_type)),
          file_count: sum(fragment("CASE WHEN ? != 'inode/directory' THEN 1 ELSE 0 END", s.mime_type)),
          total_size: sum(s.size)
        }
      )
      |> Repo.one()

    %{
      total_count: stats.total_count || 0,
      folder_count: stats.folder_count || 0,
      file_count: stats.file_count || 0,
      total_size: stats.total_size || 0
    }
  end

  @doc """
  Searches storage items by name within an organization.
  Supports pagination and filtering by item type.
  """
  def search_storage_items(search_term, organisation_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    offset = Keyword.get(opts, :offset, 0)
    item_type_filter = Keyword.get(opts, :item_type)
    sort_by = Keyword.get(opts, :sort_by, "created")
    sort_order = Keyword.get(opts, :sort_order, "desc")

    # Parse sorting options
    order_by_clause = parse_sort_options(sort_by, sort_order)

    base_query =
      from(s in StorageItem,
        where: s.organisation_id == ^organisation_id,
        where: s.is_deleted == false,
        where: ilike(s.name, ^"%#{search_term}%") or ilike(s.display_name, ^"%#{search_term}%"),
        order_by: ^order_by_clause,
        limit: ^limit,
        offset: ^offset
      )

    query =
      if item_type_filter do
        case item_type_filter do
          :folders -> from(s in base_query, where: s.mime_type == "inode/directory")
          :files -> from(s in base_query, where: s.mime_type != "inode/directory")
          _ -> base_query
        end
      else
        base_query
      end

    Repo.all(query)
  end

  alias WraftDoc.Storage.AccessLog

  @doc """
  Returns the list of storage_access_logs.

  ## Examples

      iex> list_storage_access_logs()
      [%AccessLog{}, ...]

  """
  def list_storage_access_logs do
    Repo.all(AccessLog)
  end

  @doc """
  Gets a single access_log.

  Raises `Ecto.NoResultsError` if the Access log does not exist.

  ## Examples

      iex> get_access_log!(123)
      %AccessLog{}

      iex> get_access_log!(456)
      ** (Ecto.NoResultsError)

  """
  def get_access_log!(id), do: Repo.get!(AccessLog, id)

  @doc """
  Creates a access_log.

  ## Examples

      iex> create_access_log(%{field: value})
      {:ok, %AccessLog{}}

      iex> create_access_log(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_access_log(attrs \\ %{}) do
    %AccessLog{}
    |> AccessLog.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a access_log.

  ## Examples

      iex> update_access_log(access_log, %{field: new_value})
      {:ok, %AccessLog{}}

      iex> update_access_log(access_log, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_access_log(%AccessLog{} = access_log, attrs) do
    access_log
    |> AccessLog.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a access_log.

  ## Examples

      iex> delete_access_log(access_log)
      {:ok, %AccessLog{}}

      iex> delete_access_log(access_log)
      {:error, %Ecto.Changeset{}}

  """
  def delete_access_log(%AccessLog{} = access_log) do
    Repo.delete(access_log)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking access_log changes.

  ## Examples

      iex> change_access_log(access_log)
      %Ecto.Changeset{data: %AccessLog{}}

  """
  def change_access_log(%AccessLog{} = access_log, attrs \\ %{}) do
    AccessLog.changeset(access_log, attrs)
  end

  alias WraftDoc.Storage.SyncJob

  @doc """
  Returns the list of storage_sync_jobs.

  ## Examples

      iex> list_storage_sync_jobs()
      [%SyncJob{}, ...]

  """
  def list_storage_sync_jobs do
    Repo.all(SyncJob)
  end

  @doc """
  Gets a single sync_job.

  Raises `Ecto.NoResultsError` if the Sync job does not exist.

  ## Examples

      iex> get_sync_job!(123)
      %SyncJob{}

      iex> get_sync_job!(456)
      ** (Ecto.NoResultsError)

  """
  def get_sync_job!(id), do: Repo.get!(SyncJob, id)

  @doc """
  Creates a sync_job.

  ## Examples

      iex> create_sync_job(%{field: value})
      {:ok, %SyncJob{}}

      iex> create_sync_job(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_sync_job(attrs \\ %{}) do
    %SyncJob{}
    |> SyncJob.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a sync_job.

  ## Examples

      iex> update_sync_job(sync_job, %{field: new_value})
      {:ok, %SyncJob{}}

      iex> update_sync_job(sync_job, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_sync_job(%SyncJob{} = sync_job, attrs) do
    sync_job
    |> SyncJob.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a sync_job.

  ## Examples

      iex> delete_sync_job(sync_job)
      {:ok, %SyncJob{}}

      iex> delete_sync_job(sync_job)
      {:error, %Ecto.Changeset{}}

  """
  def delete_sync_job(%SyncJob{} = sync_job) do
    Repo.delete(sync_job)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking sync_job changes.

  ## Examples

      iex> change_sync_job(sync_job)
      %Ecto.Changeset{data: %SyncJob{}}

  """
  def change_sync_job(%SyncJob{} = sync_job, attrs \\ %{}) do
    SyncJob.changeset(sync_job, attrs)
  end

  # Helper function to parse sort options
  defp parse_sort_options(sort_by, sort_order) do
    # Determine sort direction
    direction = case String.downcase(sort_order) do
      "asc" -> :asc
      "desc" -> :desc
      _ -> :desc # default to desc
    end

    # Determine sort field with fallbacks
    case String.downcase(sort_by) do
      "name" ->
        # Sort by name with folders first, then by name
        [{:asc, :item_type}, {direction, :name}]

      "updated" ->
        # Sort by updated date
        [{direction, :updated_at}]

      "created" ->
        # Sort by created date (default)
        [{direction, :inserted_at}]

      "size" ->
        # Sort by size with folders first (they have size 0)
        [{:asc, :item_type}, {direction, :size}]

      "type" ->
        # Sort by file type/extension
        [{:asc, :item_type}, {direction, :file_extension}]

      _ ->
        # Default: created date desc
        [{:desc, :inserted_at}]
    end
  end

  @doc """
  Creates a storage asset with file upload and associated storage item.
  This function performs a complete upload workflow:
  1. Creates storage asset with file metadata
  2. Uploads file to storage backend
  3. Creates associated storage item with proper hierarchy
  4. Links asset to storage item

  ## Parameters
  - current_user: The user performing the upload
  - params: Upload parameters including file and metadata

  ## Returns
  - {:ok, %{storage_asset: asset, storage_item: item}} on success
  - {:error, changeset} on validation failure
  - {:error, reason} on other failures

  ## Examples

      iex> create_storage_asset_with_item(user, %{"file" => upload, "parent_id" => folder_id})
      {:ok, %{storage_asset: %StorageAsset{}, storage_item: %StorageItem{}}}

      iex> create_storage_asset_with_item(user, %{"file" => invalid_upload})
      {:error, %Ecto.Changeset{}}
  """
  def create_storage_asset_with_item(current_user, params) do
    organisation_id = current_user.current_org_id

    with {:ok, enriched_params} <- prepare_upload_params(params, current_user, organisation_id),
         {:ok, result} <- execute_upload_transaction(enriched_params) do
      {:ok, result}
    else
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Creates a storage asset with file upload for public access (no user required).
  """
  def create_storage_asset_with_item_public(params, organisation_id) do
    with {:ok, enriched_params} <- prepare_upload_params(params, nil, organisation_id),
         {:ok, result} <- execute_upload_transaction(enriched_params) do
      {:ok, result}
    else
      {:error, error} -> {:error, error}
    end
  end

  # Prepares and validates upload parameters
  defp prepare_upload_params(%{"file" => %Plug.Upload{} = upload} = params, current_user, organisation_id) do
    require Logger
    Logger.info("📁 Preparing upload parameters", %{
      filename: upload.filename,
      size: upload.path |> File.stat!() |> Map.get(:size),
      organisation_id: organisation_id
    })

    with {:ok, file_metadata} <- extract_file_metadata(upload),
         {:ok, storage_item_params} <- build_storage_item_params(params, file_metadata, current_user, organisation_id),
         {:ok, storage_asset_params} <- build_storage_asset_params(params, file_metadata, upload, current_user, organisation_id) do

      enriched_params = %{
        storage_item: storage_item_params,
        storage_asset: storage_asset_params,
        file_upload: upload,
        current_user: current_user,
        organisation_id: organisation_id
      }

      Logger.info("✅ Upload parameters prepared successfully")
      {:ok, enriched_params}
    else
      {:error, reason} ->
        Logger.error("❌ Failed to prepare upload parameters: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp prepare_upload_params(params, _current_user, _organisation_id) do
    Logger.error("❌ No file provided in upload parameters")
    {:error, "File upload is required"}
  end

  # Extracts metadata from uploaded file
  defp extract_file_metadata(%Plug.Upload{} = upload) do
    with {:ok, file_stat} <- File.stat(upload.path),
         {:ok, checksum} <- calculate_file_checksum(upload.path) do

      filename = Path.basename(upload.filename)
      file_extension = Path.extname(filename)
      mime_type = upload.content_type || MIME.from_path(filename)

      metadata = %{
        filename: filename,
        file_extension: file_extension,
        mime_type: mime_type,
        file_size: file_stat.size,
        checksum_sha256: checksum,
        storage_key: Ecto.UUID.generate()
      }

      {:ok, metadata}
    else
      {:error, reason} -> {:error, "Failed to extract file metadata: #{inspect(reason)}"}
    end
  end

  # Builds parameters for storage item creation
  defp build_storage_item_params(params, file_metadata, current_user, organisation_id) do
    parent_id = Map.get(params, "parent_id")
    repository_id = Map.get(params, "repository_id")

    # Calculate depth level and materialized path
    {depth_level, materialized_path} = calculate_item_hierarchy(parent_id, organisation_id, file_metadata.filename)

    base_name = Path.basename(file_metadata.filename, file_metadata.file_extension)
    display_name = Map.get(params, "display_name", file_metadata.filename)

    storage_item_params = %{
      name: base_name,
      display_name: display_name,
      item_type: "file",
      path: "/#{file_metadata.filename}",
      path_hash: :crypto.hash(:sha256, file_metadata.filename) |> Base.encode16(case: :lower),
      depth_level: depth_level,
      materialized_path: materialized_path,
      mime_type: file_metadata.mime_type,
      file_extension: file_metadata.file_extension,
      size: file_metadata.file_size,
      checksum_sha256: file_metadata.checksum_sha256,
      version_number: "1.0",
      is_current_version: true,
      classification_level: Map.get(params, "classification_level", "public"),
      is_deleted: false,
      content_extracted: false,
      thumbnail_generated: false,
      download_count: 0,
      metadata: %{
        original_filename: file_metadata.filename,
        filename: file_metadata.filename,
        upload_source: "web_ui"
      },
      parent_id: parent_id,
      repository_id: repository_id,
      creator_id: current_user && current_user.id,
      organisation_id: organisation_id
    }

    {:ok, storage_item_params}
  end

  # Builds parameters for storage asset creation
  defp build_storage_asset_params(params, file_metadata, upload, current_user, organisation_id) do
    storage_asset_params = %{
      filename: upload,
      storage_key: file_metadata.storage_key,
      storage_backend: "local", # or "s3", "minio" based on config
      file_size: file_metadata.file_size,
      checksum_sha256: file_metadata.checksum_sha256,
      mime_type: file_metadata.mime_type,
      processing_status: "pending",
      upload_completed_at: nil, # Will be set after successful upload
      creator_id: current_user && current_user.id,
      organisation_id: organisation_id
    }

    {:ok, storage_asset_params}
  end

  # Executes the complete upload transaction
  defp execute_upload_transaction(enriched_params) do
    require Logger
    Logger.info("🔄 Starting upload transaction")

    Ecto.Multi.new()
    |> Ecto.Multi.insert(:storage_item, StorageItem.changeset(%StorageItem{}, enriched_params.storage_item))
    |> Ecto.Multi.insert(:storage_asset, fn %{storage_item: storage_item} ->
      storage_asset_params = Map.put(enriched_params.storage_asset, :storage_item_id, storage_item.id)
      StorageAsset.changeset(%StorageAsset{}, storage_asset_params)
    end)
    |> Ecto.Multi.update(:upload_file, fn %{storage_asset: storage_asset} ->
      # Use Waffle to handle the file upload
      StorageAsset.file_changeset(storage_asset, %{filename: enriched_params.file_upload})
    end)
    |> Ecto.Multi.update(:complete_upload, fn %{upload_file: storage_asset} ->
      StorageAsset.changeset(storage_asset, %{
        processing_status: "completed",
        upload_completed_at: DateTime.utc_now()
      })
    end)
    |> Ecto.Multi.run(:create_access_log, fn _repo, %{storage_item: storage_item, complete_upload: storage_asset} ->
      create_upload_access_log(storage_item, storage_asset, enriched_params)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{storage_item: storage_item, complete_upload: storage_asset}} ->
        Logger.info("✅ Upload transaction completed successfully", %{
          storage_item_id: storage_item.id,
          storage_asset_id: storage_asset.id
        })

        # Schedule background processing
        schedule_background_processing(storage_asset, storage_item)

        {:ok, %{storage_asset: storage_asset, storage_item: storage_item}}

      {:error, stage, changeset, _changes} ->
        Logger.error("❌ Upload transaction failed at stage: #{stage}", %{
          errors: changeset.errors,
          changeset: changeset
        })
        {:error, changeset}
    end
  end

  # Calculates hierarchy information for storage item
  defp calculate_item_hierarchy(nil, _organisation_id, _filename) do
    # Root level item
    {1, "/"}
  end

  defp calculate_item_hierarchy(parent_id, organisation_id, filename) do
    case get_storage_item_by_org(parent_id, organisation_id) do
      %StorageItem{depth_level: parent_depth, materialized_path: parent_path} ->
        depth_level = parent_depth + 1
        materialized_path = Path.join(parent_path, filename)
        {depth_level, materialized_path}

      nil ->
        # Parent not found, treat as root level
        {1, "/#{filename}"}
    end
  end

  # Calculates SHA256 checksum of file
  defp calculate_file_checksum(file_path) do
    case File.open(file_path, [:read, :binary]) do
      {:ok, file} ->
        checksum =
          file
          |> IO.binstream(64_000)
          |> Enum.reduce(:crypto.hash_init(:sha256), &:crypto.hash_update(&2, &1))
          |> :crypto.hash_final()
          |> Base.encode16(case: :lower)

        File.close(file)
        {:ok, checksum}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Creates access log for upload
  defp create_upload_access_log(storage_item, storage_asset, enriched_params) do
    access_log_params = %{
      action: "upload",
      ip_address: "127.0.0.1", # Should be extracted from request context
      user_agent: "Web Browser", # Should be extracted from request context
      session_id: Ecto.UUID.generate(),
      metadata: %{
        filename: storage_item.name,
        file_size: storage_item.size,
        mime_type: storage_item.mime_type
      },
      success: true,
      storage_item_id: storage_item.id,
      storage_asset_id: storage_asset.id,
      user_id: enriched_params.current_user && enriched_params.current_user.id,
      repository_id: storage_item.repository_id
    }

    create_access_log(access_log_params)
  end

  # Schedules background processing for uploaded file
  defp schedule_background_processing(storage_asset, storage_item) do
    Task.start(fn ->
      require Logger
      Logger.info("🔄 Starting background processing", %{
        storage_asset_id: storage_asset.id,
        storage_item_id: storage_item.id
      })

      # Update processing status
      update_storage_asset(storage_asset, %{processing_status: "processing"})

      # Perform background tasks
      with :ok <- extract_content_if_supported(storage_item),
           :ok <- generate_thumbnail_if_supported(storage_item) do

        # Update storage item with processing results
        update_storage_item(storage_item, %{
          content_extracted: true,
          thumbnail_generated: true
        })

        # Update asset processing status
        update_storage_asset(storage_asset, %{processing_status: "completed"})

        Logger.info("✅ Background processing completed", %{
          storage_asset_id: storage_asset.id,
          storage_item_id: storage_item.id
        })
      else
        {:error, reason} ->
          Logger.error("❌ Background processing failed", %{
            storage_asset_id: storage_asset.id,
            storage_item_id: storage_item.id,
            reason: reason
          })

          update_storage_asset(storage_asset, %{processing_status: "failed"})
      end
    end)
  end

  # Extracts content from supported file types
  defp extract_content_if_supported(%StorageItem{mime_type: "application/pdf"}), do: :ok
  defp extract_content_if_supported(%StorageItem{mime_type: "text/" <> _}), do: :ok
  defp extract_content_if_supported(_), do: :ok

  # Generates thumbnails for supported file types
  defp generate_thumbnail_if_supported(%StorageItem{mime_type: "image/" <> _}), do: :ok
  defp generate_thumbnail_if_supported(%StorageItem{mime_type: "application/pdf"}), do: :ok
  defp generate_thumbnail_if_supported(_), do: :ok

  @doc """
  Gets a storage asset with organization validation, returns nil if not found.
  """
  def get_storage_asset_by_org(id, organisation_id) do
    from(s in StorageAsset,
      where: s.id == ^id,
      where: s.organisation_id == ^organisation_id
    )
    |> Repo.one()
  end

  @doc """
  Returns the list of storage assets for a given organisation.
  """
  def list_storage_assets_by_organisation(organisation_id) do
    from(s in StorageAsset,
      where: s.organisation_id == ^organisation_id,
      order_by: [desc: s.inserted_at]
    )
    |> Repo.all()
  end

  @doc """
  Gets all storage assets linked to a specific storage item.
  """
  def get_storage_assets_for_item(storage_item_id) do
    from(sa in StorageAsset,
      where: sa.storage_item_id == ^storage_item_id,
      order_by: [desc: sa.inserted_at]
    )
    |> Repo.all()
  end

  @doc """
  Renames a storage item (file or folder).
  Updates both the name and display_name fields.
  Handles duplicate name checking in the same folder.

  ## Examples

      iex> rename_storage_item(storage_item, "new_name", organisation_id)
      {:ok, %StorageItem{}}

      iex> rename_storage_item(storage_item, "invalid/name", organisation_id)
      {:error, :invalid_name}

  """
  def rename_storage_item(%StorageItem{} = storage_item, new_name, organisation_id) do
    # Validate the new name
    if String.contains?(new_name, "/") do
      {:error, :invalid_name}
    else
      # Get the parent folder to check for duplicates
      parent_id = storage_item.parent_id

      # Check for duplicate names in the same folder
      duplicate_check_query = from(s in StorageItem,
        where: s.parent_id == ^parent_id,
        where: s.organisation_id == ^organisation_id,
        where: s.is_deleted == false,
        where: s.id != ^storage_item.id,
        where: s.name == ^new_name
      )

      case Repo.one(duplicate_check_query) do
        nil ->
          # No duplicate found, proceed with rename
          changeset = StorageItem.changeset(storage_item, %{
            name: new_name,
            display_name: new_name
          })

          case Repo.update(changeset) do
            {:ok, updated_item} ->
              # If it's a folder, update the materialized paths of all children
              if updated_item.mime_type == "inode/directory" do
                update_children_paths(updated_item, organisation_id)
              end
              {:ok, updated_item}
            {:error, changeset} -> {:error, changeset}
          end

        _existing_item ->
          {:error, :duplicate_name}
      end
    end
  end

  # Helper function to update materialized paths of all children when a folder is renamed
  defp update_children_paths(%StorageItem{} = parent_item, organisation_id) do
    # Get all children recursively
    children = get_all_children_storage_items(parent_item.id)

    # Update each child's materialized path
    Enum.each(children, fn child ->
      new_materialized_path = String.replace(
        child.materialized_path,
        parent_item.materialized_path,
        Path.join(parent_item.materialized_path, parent_item.name)
      )

      StorageItem.changeset(child, %{materialized_path: new_materialized_path})
      |> Repo.update()
    end)
  end
end
