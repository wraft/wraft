defmodule WraftDoc.Storage.StorageItems do
  @moduledoc """
  Storage items management - handles CRUD operations, navigation, and organization
  of storage items including files and folders.

  This module provides functionality for:
  - Creating, reading, updating, and deleting storage items
  - Managing hierarchical folder structures with breadcrumb navigation
  - Handling file uploads and asset creation
  - Searching and filtering storage items
  - Managing storage item statistics and metadata
  - Soft deletion and recovery operations

  ## Storage Item Structure

  Storage items represent both files and folders in a hierarchical structure:
  - Files contain actual content and have associated storage assets
  - Folders (mime_type: "inode/directory") organize other items
  - Each item has a materialized path for efficient hierarchy queries
  - Items support versioning, classification levels, and metadata

  ## Examples

      # List root level items for an organization
      iex> list_storage_items(nil, "org-123")
      [%StorageItem{}, ...]

      # Get breadcrumb navigation for an item
      iex> get_storage_item_breadcrumb_navigation("item-456", "org-123")
      [%{id: "root", name: "Documents", is_folder: true}, ...]

      # Search for items by name
      iex> search_storage_items("contract", "org-123", limit: 10)
      [%StorageItem{name: "contract.pdf"}, ...]
  """

  require Logger
  import Ecto.Query, warn: false
  alias WraftDoc.Repo
  alias WraftDoc.Storage, as: Helper
  alias WraftDoc.Storage.StorageAsset
  alias WraftDoc.Storage.StorageAssets
  alias WraftDoc.Storage.StorageItem

  @type storage_item_opts :: [
          limit: pos_integer(),
          offset: non_neg_integer(),
          sort_by: String.t(),
          sort_order: String.t()
        ]

  @type breadcrumb_item :: %{
          id: String.t(),
          name: String.t(),
          is_folder: boolean(),
          path: String.t(),
          materialized_path: String.t()
        }

  @type storage_stats :: %{
          total_count: non_neg_integer(),
          folder_count: non_neg_integer(),
          file_count: non_neg_integer(),
          total_size: non_neg_integer()
        }

  @type navigation_response :: %{
          data: %{
            items: [map()],
            breadcrumbs: [breadcrumb_item()]
          },
          meta: %{
            count: non_neg_integer(),
            timestamp: DateTime.t()
          }
        }

  @doc """
  Returns the list of storage items based on parent and organization filters.

  ## Parameters
  - `parent_id` - UUID of parent folder, or `nil` for root level items
  - `organisation_id` - UUID of the organization
  - `opts` - Keyword list of options for pagination and sorting

  ## Options
  - `:limit` - Maximum number of items to return (default: 100)
  - `:offset` - Number of items to skip (default: 0)
  - `:sort_by` - Field to sort by: "created", "name", "size" (default: "created")
  - `:sort_order` - Sort direction: "asc" or "desc" (default: "desc")

  ## Examples

      iex> list_storage_items(nil, "org-123")
      [%StorageItem{}, ...]

      iex> list_storage_items("parent-456", "org-123", limit: 50, sort_by: "name")
      [%StorageItem{}, ...]
  """
  @spec list_storage_items(String.t() | nil, String.t() | nil, storage_item_opts()) :: [
          StorageItem.t()
        ]
  def list_storage_items(parent_id \\ nil, organisation_id \\ nil, opts \\ [])

  def list_storage_items(nil, nil, _opts) do
    Repo.all(StorageItem)
  end

  def list_storage_items(parent_id, organisation_id, opts) when is_binary(organisation_id) do
    limit = Keyword.get(opts, :limit, 100)
    offset = Keyword.get(opts, :offset, 0)
    sort_by = Keyword.get(opts, :sort_by, "created")
    sort_order = Keyword.get(opts, :sort_order, "desc")

    # Parse sorting options
    order_by_clause = Helper.parse_sort_options(sort_by, sort_order)

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
        from(s in base_query,
          where: is_nil(s.parent_id) and s.depth_level == 1
        )
      end

    Repo.all(query)
  end

  def list_storage_items(parent_id, organisation_id, opts) do
    list_storage_items(parent_id, to_string(organisation_id), opts)
  end

  @doc """
  Gets a single storage item by ID.

  Raises `Ecto.NoResultsError` if the storage item does not exist.

  ## Examples

      iex> get_storage_item!("valid-uuid")
      %StorageItem{}

      iex> get_storage_item!("invalid-uuid")
      ** (Ecto.NoResultsError)
  """
  @spec get_storage_item!(String.t()) :: StorageItem.t()
  def get_storage_item!(id), do: Repo.get!(StorageItem, id)

  @doc """
  Updates file upload status to completed.
  """
  @spec update_upload_status(StorageItem.t(), String.t()) ::
          {:ok, StorageItem.t()} | {:error, Ecto.Changeset.t()} | {}
  def update_upload_status(%StorageItem{} = storage_item, status),
    do: update_storage_item(storage_item, %{"upload_status" => status})

  def update_upload_status(external_id, status) do
    StorageItem
    |> where([s], s.external_id == ^external_id)
    |> Repo.update_all(set: [upload_status: status])
  end

  @doc """
  Creates a storage item with the given attributes.

  Handles duplicate external_id gracefully by returning the existing item
  if a duplicate constraint violation occurs.

  ## Parameters
  - `attrs` - Map of attributes for the storage item

  ## Returns
  - `{:ok, storage_item}` - Successfully created or found existing item
  - `{:error, changeset}` - Validation or other errors occurred

  ## Examples

      iex> create_storage_item(%{name: "document.pdf", organisation_id: "org-123"})
      {:ok, %StorageItem{}}

      iex> create_storage_item(%{name: ""})
      {:error, %Ecto.Changeset{}}
  """
  @spec create_storage_item(map()) :: {:ok, StorageItem.t()} | {:error, Ecto.Changeset.t()}
  def create_storage_item(attrs \\ %{}) do
    attrs =
      attrs
      |> Map.put("parent_id", attrs["parent_id"])
      |> Helper.handle_duplicate_names()

    %StorageItem{}
    |> StorageItem.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, storage_item} ->
        {:ok, storage_item}

      {:error, changeset} ->
        if duplicate_external_id_error?(changeset) do
          get_existing_storage_item(attrs)
        else
          {:error, changeset}
        end
    end
  end

  @spec duplicate_external_id_error?(Ecto.Changeset.t()) :: boolean()
  defp duplicate_external_id_error?(%Ecto.Changeset{errors: errors}) do
    case Keyword.get(errors, :external_id) do
      {"has already been taken", opts} ->
        Keyword.get(opts, :constraint_name) == "storage_items_external_id_sync_source_index"

      _ ->
        false
    end
  end

  @spec get_existing_storage_item(map()) ::
          {:ok, StorageItem.t()} | {:error, :not_found | :invalid_lookup_keys}
  defp get_existing_storage_item(%{"external_id" => ext_id, "sync_source" => sync} = _attrs)
       when not is_nil(ext_id) and not is_nil(sync) do
    case Repo.get_by(StorageItem, external_id: ext_id, sync_source: sync) do
      nil -> {:error, :not_found}
      existing -> {:ok, existing}
    end
  end

  defp get_existing_storage_item(_), do: {:ok, :invalid_lookup_keys}

  @doc """
  Updates a storage item with the given attributes.

  ## Examples

      iex> update_storage_item(storage_item, %{name: "new_name.pdf"})
      {:ok, %StorageItem{}}

      iex> update_storage_item(storage_item, %{name: ""})
      {:error, %Ecto.Changeset{}}
  """
  @spec update_storage_item(StorageItem.t(), map()) ::
          {:ok, StorageItem.t()} | {:error, Ecto.Changeset.t()}
  def update_storage_item(%StorageItem{} = storage_item, attrs) do
    storage_item
    |> StorageItem.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a storage item (soft delete).

  For folders, schedules recursive deletion of all children.
  Also schedules deletion of associated storage assets.

  ## Examples

      iex> delete_storage_item(storage_item)
      {:ok, %StorageItem{is_deleted: true}}
  """
  @spec delete_storage_item(StorageItem.t()) :: {:ok, any()} | {:error, any()}
  def delete_storage_item(%StorageItem{} = storage_item) do
    Repo.transaction(fn ->
      # Mark the item as deleted
      storage_item
      |> StorageItem.changeset(%{
        is_deleted: true,
        deleted_at: DateTime.utc_now()
      })
      |> Repo.update()

      if storage_item.mime_type == "inode/directory" do
        Helper.schedule_folder_deletion(storage_item.id)
      end

      StorageAssets.schedule_asset_deletion(storage_item.id)
    end)
  end

  @doc """
  Gets the breadcrumb trail for a storage item.

  Returns a list of ancestor items from root to the specified item.

  ## Examples

      iex> get_storage_item_breadcrumbs("item-123", "org-456")
      [%StorageItem{name: "Documents"}, %StorageItem{name: "Contracts"}]
  """
  @spec get_storage_item_breadcrumbs(String.t(), String.t()) :: [StorageItem.t()]
  def get_storage_item_breadcrumbs(item_id, organisation_id) do
    case get_storage_item_by_org(item_id, organisation_id) do
      nil -> []
      item -> Helper.build_storage_ancestors(item, organisation_id, [])
    end
  end

  @doc """
  Gets breadcrumb navigation data for a storage item.

  Returns a simplified list of breadcrumb items suitable for UI navigation.

  ## Examples

      iex> get_storage_item_breadcrumb_navigation("item-123", "org-456")
      [%{id: "root", name: "Documents", is_folder: true, path: "/docs"}]
  """
  @spec get_storage_item_breadcrumb_navigation(String.t(), String.t()) :: [breadcrumb_item()]
  def get_storage_item_breadcrumb_navigation(item_id, organisation_id) do
    item_id
    |> get_storage_item_breadcrumbs(organisation_id)
    |> Enum.map(&map_breadcrumb_item/1)
  end

  @spec map_breadcrumb_item(StorageItem.t()) :: breadcrumb_item()
  defp map_breadcrumb_item(
         %{
           id: id,
           mime_type: mime_type,
           path: path,
           materialized_path: materialized_path
         } = item
       ) do
    %{
      id: id,
      name: Helper.get_meaningful_name(item),
      is_folder: mime_type == "inode/directory",
      path: path,
      materialized_path: materialized_path
    }
  end

  @doc """
  Returns an `Ecto.Changeset` for tracking storage item changes.

  ## Examples

      iex> change_storage_item(storage_item)
      %Ecto.Changeset{data: %StorageItem{}}
  """
  @spec change_storage_item(StorageItem.t(), map()) :: Ecto.Changeset.t()
  def change_storage_item(%StorageItem{} = storage_item, attrs \\ %{}),
    do: StorageItem.changeset(storage_item, attrs)

  @spec now_utc() :: DateTime.t()
  defp now_utc, do: DateTime.utc_now()

  @doc """
  Performs a soft delete on a storage item and its children (if folder).

  ## Examples

      iex> soft_delete_storage_item(storage_item)
      {:ok, %StorageItem{is_deleted: true}}
  """
  @spec soft_delete_storage_item(StorageItem.t()) :: {:ok, any()} | {:error, any()}
  def soft_delete_storage_item(%StorageItem{} = storage_item),
    do: Repo.transaction(fn -> perform_soft_delete(storage_item) end)

  @spec perform_soft_delete(StorageItem.t()) ::
          {:ok, StorageItem.t()} | {:error, Ecto.Changeset.t()}
  defp perform_soft_delete(%StorageItem{} = storage_item) do
    maybe_soft_delete_children(storage_item, now_utc())
    soft_delete_item(storage_item, now_utc())
  end

  @spec maybe_soft_delete_children(StorageItem.t(), DateTime.t()) :: :ok | {integer(), nil}
  defp maybe_soft_delete_children(%StorageItem{mime_type: "inode/directory", id: id}, now) do
    children = get_all_children_storage_items(id)

    unless Enum.empty?(children) do
      child_ids = Enum.map(children, & &1.id)

      q = from(s in StorageItem, where: s.id in ^child_ids)
      Repo.update_all(q, set: [is_deleted: true, deleted_at: now])
    end
  end

  defp maybe_soft_delete_children(_storage_item, _now), do: :ok

  @spec soft_delete_item(StorageItem.t(), DateTime.t()) ::
          {:ok, StorageItem.t()} | {:error, Ecto.Changeset.t()}
  defp soft_delete_item(storage_item, now) do
    storage_item
    |> StorageItem.changeset(%{is_deleted: true, deleted_at: now})
    |> Repo.update()
  end

  def get_storage_item_by_path(organisation_id, materialized_path) do
    Repo.one(
      from(s in StorageItem,
        where:
          s.organisation_id == ^organisation_id and
            s.materialized_path == ^materialized_path and
            s.is_deleted == false
      )
    )
  end

  @doc """
  Gets all children of a storage item recursively (for folders).

  ## Examples

      iex> get_all_children_storage_items("folder-123")
      [%StorageItem{}, %StorageItem{}, ...]
  """
  @spec get_all_children_storage_items(String.t()) :: [StorageItem.t()]
  def get_all_children_storage_items(parent_id) do
    parent_id
    |> fetch_immediate_children()
    |> Enum.flat_map(fn child ->
      process_child(child)
    end)
  end

  @spec fetch_immediate_children(String.t()) :: [StorageItem.t()]
  defp fetch_immediate_children(parent_id) do
    fetch =
      from(s in StorageItem,
        where: s.parent_id == ^parent_id and s.is_deleted == false
      )

    Repo.all(fetch)
  end

  @spec process_child(StorageItem.t()) :: [StorageItem.t()]
  defp process_child(%StorageItem{mime_type: "inode/directory", id: id} = child) do
    [child | get_all_children_storage_items(id)]
  end

  defp process_child(child), do: [child]

  @doc """
  Lists storage items with breadcrumb navigation data.

  Returns items along with breadcrumb trail and current folder information.

  ## Examples

      iex> list_storage_items_with_breadcrumbs("parent-123", "org-456")
      %{items: [...], breadcrumbs: [...], current_folder: %{...}}
  """
  @spec list_storage_items_with_breadcrumbs(String.t() | nil, String.t(), storage_item_opts()) ::
          %{
            items: [StorageItem.t()],
            breadcrumbs: [breadcrumb_item()],
            current_folder: map() | nil
          }
  def list_storage_items_with_breadcrumbs(parent_id \\ nil, organisation_id, opts \\ []) do
    items = list_storage_items(parent_id, organisation_id, opts)
    {breadcrumbs, current_folder} = build_breadcrumbs_and_folder(parent_id, organisation_id)

    %{
      items: items,
      breadcrumbs: breadcrumbs,
      current_folder: current_folder
    }
  end

  @spec build_breadcrumbs_and_folder(String.t() | nil, String.t()) ::
          {[breadcrumb_item()], map() | nil}
  defp build_breadcrumbs_and_folder(nil, _organisation_id), do: {[], nil}

  defp build_breadcrumbs_and_folder(parent_id, organisation_id) do
    case get_storage_item_by_org(parent_id, organisation_id) do
      %StorageItem{} = folder ->
        breadcrumbs = Helper.get_ancestors_breadcrumbs(folder, organisation_id)
        current_folder = build_folder_map(folder)
        {breadcrumbs, current_folder}

      nil ->
        {[], nil}
    end
  end

  @spec build_folder_map(StorageItem.t()) :: map()
  defp build_folder_map(
         %StorageItem{
           id: id,
           mime_type: mime_type,
           path: path,
           materialized_path: materialized_path
         } = folder
       ) do
    %{
      id: id,
      name: Helper.get_meaningful_name(folder),
      is_folder: mime_type == "inode/directory",
      path: path,
      materialized_path: materialized_path
    }
  end

  @doc """
  Finds a storage item by its path within an organization.

  ## Examples

      iex> find_storage_item_by_path("/documents/contract.pdf", "org-123")
      %StorageItem{}

      iex> find_storage_item_by_path("/nonexistent", "org-123")
      nil
  """
  @spec find_storage_item_by_path(String.t(), String.t()) :: StorageItem.t() | nil
  def find_storage_item_by_path(path, organisation_id) do
    query =
      from(s in StorageItem,
        where: s.organisation_id == ^organisation_id,
        where: s.is_deleted == false,
        where: s.materialized_path == ^path or s.path == ^path,
        limit: 1
      )

    Repo.one(query)
  end

  @doc """
  Lists storage items by repository with pagination.

  ## Examples

      iex> list_storage_items_by_repository("repo-123", "org-456", limit: 20)
      [%StorageItem{}, ...]
  """
  @spec list_storage_items_by_repository(String.t(), String.t(), storage_item_opts()) :: [
          StorageItem.t()
        ]
  def list_storage_items_by_repository(repository_id, organisation_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)
    offset = Keyword.get(opts, :offset, 0)

    query =
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

    Repo.all(query)
  end

  @doc """
  Lists storage items by parent with sorting and pagination.

  ## Examples

      iex> list_storage_items_by_parent("parent-123", "org-456", sort_by: "name")
      [%StorageItem{}, ...]
  """
  @spec list_storage_items_by_parent(String.t(), String.t(), storage_item_opts()) :: [
          StorageItem.t()
        ]
  def list_storage_items_by_parent(parent_id, organisation_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)
    offset = Keyword.get(opts, :offset, 0)
    sort_by = Keyword.get(opts, :sort_by, "created")
    sort_order = Keyword.get(opts, :sort_order, "desc")
    order_by_clause = Helper.parse_sort_options(sort_by, sort_order)

    query =
      from(s in StorageItem,
        where: s.parent_id == ^parent_id,
        where: s.organisation_id == ^organisation_id,
        where: s.is_deleted == false,
        order_by: ^order_by_clause,
        limit: ^limit,
        offset: ^offset
      )

    Repo.all(query)
  end

  @doc """
  Lists root level storage items for an organization.

  ## Examples

      iex> list_root_storage_items("org-123", limit: 50)
      [%StorageItem{}, ...]
  """
  @spec list_root_storage_items(String.t(), storage_item_opts()) :: [StorageItem.t()]
  def list_root_storage_items(organisation_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)
    offset = Keyword.get(opts, :offset, 0)

    query =
      from(s in StorageItem,
        where: is_nil(s.parent_id),
        where: s.depth_level == 1,
        where: s.organisation_id == ^organisation_id,
        where: s.is_deleted == false,
        order_by: [asc: s.item_type, asc: s.name],
        limit: ^limit,
        offset: ^offset
      )

    Repo.all(query)
  end

  @doc """
  Gets a storage item by ID and organization, raising if not found.

  ## Examples

      iex> get_storage_item_by_org!("item-123", "org-456")
      %StorageItem{}

      iex> get_storage_item_by_org!("nonexistent", "org-456")
      ** (Ecto.NoResultsError)
  """
  @spec get_storage_item_by_org!(String.t(), String.t()) :: StorageItem.t()
  def get_storage_item_by_org!(id, organisation_id) do
    query =
      from(s in StorageItem,
        where: s.id == ^id,
        where: s.organisation_id == ^organisation_id,
        where: s.is_deleted == false
      )

    Repo.one!(query)
  end

  def get_folder(nil, _organisation_id) do
    %StorageItem{
      id: nil,
      mime_type: "inode/directory",
      is_deleted: false,
      repository_id: nil,
      materialized_path: "/",
      depth_level: 1,
      parent_id: nil
    }
  end

  def get_folder(folder_id, organisation_id) do
    query =
      from(s in StorageItem,
        where: s.id == ^folder_id,
        where: s.mime_type == "inode/directory",
        where: s.organisation_id == ^organisation_id,
        where: s.is_deleted == false
      )

    Repo.one(query)
  end

  @doc """
  Gets a storage item by ID and organization.

  ## Examples

      iex> get_storage_item_by_org("item-123", "org-456")
      %StorageItem{}

      iex> get_storage_item_by_org("nonexistent", "org-456")
      nil
  """
  @spec get_storage_item_by_org(String.t(), String.t()) :: StorageItem.t() | nil
  def get_storage_item_by_org(id, organisation_id) do
    query =
      from(s in StorageItem,
        where: s.id == ^id,
        where: s.organisation_id == ^organisation_id,
        where: s.is_deleted == false
      )

    Repo.one(query)
  end

  def get_sync_folder(folder_name, organisation_id) do
    query =
      from(s in StorageItem,
        where: s.name == ^folder_name,
        where: s.organisation_id == ^organisation_id,
        where: s.mime_type == "inode/directory",
        where: s.is_deleted == false
      )

    Repo.one(query)
  end

  @doc """
  Counts storage items under a parent or at root level.

  ## Examples

      iex> count_storage_items("parent-123", "org-456")
      42

      iex> count_storage_items(nil, "org-456")
      15
  """
  @spec count_storage_items(String.t() | nil, String.t()) :: non_neg_integer()
  def count_storage_items(parent_id, organisation_id) when is_binary(parent_id) do
    query =
      from(s in StorageItem,
        where: s.parent_id == ^parent_id,
        where: s.organisation_id == ^organisation_id,
        where: s.is_deleted == false,
        select: count(s.id)
      )

    Repo.one(query)
  end

  def count_storage_items(nil, organisation_id) do
    query =
      from(s in StorageItem,
        where: is_nil(s.parent_id),
        where: s.depth_level == 1,
        where: s.organisation_id == ^organisation_id,
        where: s.is_deleted == false,
        select: count(s.id)
      )

    Repo.one(query)
  end

  @doc """
  Gets statistics for storage items under a parent or at root level.

  Returns counts and total size information.

  ## Examples

      iex> get_storage_item_stats("parent-123", "org-456")
      %{total_count: 10, folder_count: 3, file_count: 7, total_size: 1024000}
  """
  @spec get_storage_item_stats(String.t() | nil, String.t()) :: storage_stats()
  def get_storage_item_stats(parent_id, organisation_id) do
    organisation_id
    |> build_base_query()
    |> apply_parent_scope(parent_id)
    |> build_stats_query()
    |> Repo.one()
    |> normalize_stats()
  end

  @spec build_base_query(String.t()) :: Ecto.Query.t()
  defp build_base_query(organisation_id) do
    from(s in StorageItem,
      where: s.organisation_id == ^organisation_id,
      where: s.is_deleted == false
    )
  end

  @spec apply_parent_scope(Ecto.Query.t(), String.t() | nil) :: Ecto.Query.t()
  defp apply_parent_scope(query, nil) do
    from(s in query,
      where: is_nil(s.parent_id) and s.depth_level == 1
    )
  end

  defp apply_parent_scope(query, parent_id) do
    from(s in query,
      where: s.parent_id == ^parent_id
    )
  end

  @spec build_stats_query(Ecto.Query.t()) :: Ecto.Query.t()
  def build_stats_query(query) do
    from(s in query,
      select: %{
        total_count: count(s.id),
        folder_count:
          sum(fragment("CASE WHEN ? = 'inode/directory' THEN 1 ELSE 0 END", s.mime_type)),
        file_count:
          sum(fragment("CASE WHEN ? != 'inode/directory' THEN 1 ELSE 0 END", s.mime_type)),
        total_size: sum(s.size)
      }
    )
  end

  @spec normalize_stats(map() | nil) :: storage_stats()
  def normalize_stats(nil) do
    %{
      total_count: 0,
      folder_count: 0,
      file_count: 0,
      total_size: 0
    }
  end

  def normalize_stats(stats) do
    %{
      total_count: stats.total_count || 0,
      folder_count: stats.folder_count || 0,
      file_count: stats.file_count || 0,
      total_size: stats.total_size || 0
    }
  end

  @doc """
  Searches storage items by name or display name.

  ## Parameters
  - `search_term` - Text to search for in item names
  - `organisation_id` - Organization UUID
  - `opts` - Search options including filters and pagination

  ## Options
  - `:item_type` - Filter by type: `:folders`, `:files`, or `nil` for all
  - `:limit` - Maximum results (default: 50)
  - `:offset` - Results to skip (default: 0)
  - `:sort_by` - Sort field (default: "created")
  - `:sort_order` - Sort direction (default: "desc")

  ## Examples

      iex> search_storage_items("contract", "org-123", item_type: :files, limit: 10)
      [%StorageItem{name: "contract.pdf"}, ...]
  """
  @spec search_storage_items(String.t(), String.t(), keyword()) :: [StorageItem.t()]
  def search_storage_items(search_term, organisation_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    offset = Keyword.get(opts, :offset, 0)
    item_type_filter = Keyword.get(opts, :item_type)
    sort_by = Keyword.get(opts, :sort_by, "created")
    sort_order = Keyword.get(opts, :sort_order, "desc")
    order_by_clause = Helper.parse_sort_options(sort_by, sort_order)

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

  @doc """
  Creates a storage asset with associated storage item for authenticated users.

  Handles file upload, metadata extraction, and storage item creation in a transaction.

  ## Examples

      iex> create_storage_asset_with_item(current_user, %{"file" => upload, "parent_id" => "folder-123"})
      {:ok, %{storage_item: %StorageItem{}, storage_asset: %StorageAsset{}}}
  """
  @spec create_storage_asset_with_item(map(), map()) :: {:ok, map()} | {:error, any()}
  def create_storage_asset_with_item(current_user, params) do
    organisation_id = current_user.current_org_id

    with {:ok, enriched_params} <-
           Helper.prepare_upload_params(params, current_user, organisation_id),
         {:ok, result} <- Helper.execute_upload_transaction(enriched_params) do
      {:ok, result}
    else
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Creates a storage asset with file upload for public access (no user required).

  ## Examples

      iex> create_storage_asset_with_item_public(%{"file" => upload}, "org-123")
      {:ok, %{storage_item: %StorageItem{}, storage_asset: %StorageAsset{}}}
  """
  @spec create_storage_asset_with_item_public(map(), String.t()) :: {:ok, map()} | {:error, any()}
  def create_storage_asset_with_item_public(params, organisation_id) do
    with {:ok, enriched_params} <- Helper.prepare_upload_params(params, nil, organisation_id),
         {:ok, result} <- Helper.execute_upload_transaction(enriched_params) do
      {:ok, result}
    else
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Builds storage item parameters from upload metadata.

  ## Examples

      iex> build_storage_item_params(params, file_metadata, user, "org-123")
      {:ok, %{name: "document", mime_type: "application/pdf", ...}}
  """
  @spec build_storage_item_params(map(), map(), map() | nil, String.t()) :: {:ok, map()}
  def build_storage_item_params(params, file_metadata, current_user, organisation_id) do
    parent_id = Map.get(params, "parent_id")
    repository_id = Map.get(params, "repository_id")

    {depth_level, materialized_path} =
      Helper.calculate_item_hierarchy(parent_id, organisation_id, file_metadata.filename)

    base_name = Path.basename(file_metadata.filename, file_metadata.file_extension)
    display_name = Map.get(params, "display_name", file_metadata.filename)

    storage_item_params = %{
      "name" => base_name,
      "display_name" => display_name,
      "item_type" => "file",
      "path" => "/#{file_metadata.filename}",
      "path_hash" => Base.encode16(:crypto.hash(:sha256, file_metadata.filename), case: :lower),
      "depth_level" => depth_level,
      "materialized_path" => materialized_path,
      "mime_type" => file_metadata.mime_type,
      "file_extension" => file_metadata.file_extension,
      "size" => file_metadata.file_size,
      "checksum_sha256" => file_metadata.checksum_sha256,
      "version_number" => "1.0",
      "is_current_version" => true,
      "classification_level" => Map.get(params, "classification_level", "public"),
      "is_deleted" => false,
      "content_extracted" => false,
      "thumbnail_generated" => false,
      "download_count" => 0,
      "metadata" => %{
        "original_filename" => file_metadata.filename,
        "filename" => file_metadata.filename,
        "upload_source" => "web_ui"
      },
      "parent_id" => parent_id,
      "repository_id" => repository_id,
      "creator_id" => current_user && current_user.id,
      "organisation_id" => organisation_id,
      "upload_status" => "completed"
    }

    {:ok, storage_item_params}
  end

  @doc """
  Renames a storage item and updates children paths if it's a folder.

  ## Examples

      iex> rename_storage_item(storage_item, "new_name", "org-123")
      {:ok, %StorageItem{name: "new_name"}}

      iex> rename_storage_item(storage_item, "invalid/name", "org-123")
      {:error, :invalid_name}
  """
  @spec rename_storage_item(StorageItem.t(), String.t(), String.t()) ::
          {:ok, StorageItem.t()} | {:error, atom()}
  def rename_storage_item(%StorageItem{} = storage_item, new_name, organisation_id) do
    with :ok <- validate_name(new_name),
         :ok <- check_duplicate_name(storage_item, new_name, organisation_id),
         {:ok, updated_item} <- update_storage_item_name(storage_item, new_name) do
      maybe_update_children_paths(updated_item, organisation_id)
      {:ok, updated_item}
    end
  end

  @spec validate_name(String.t()) :: :ok | {:error, :invalid_name}
  defp validate_name(name) do
    if String.contains?(name, "/") do
      {:error, :invalid_name}
    else
      :ok
    end
  end

  @spec check_duplicate_name(StorageItem.t(), String.t(), String.t()) ::
          :ok | {:error, :duplicate_name}
  defp check_duplicate_name(storage_item, new_name, organisation_id) do
    duplicate_check_query =
      from(s in StorageItem,
        where: s.parent_id == ^storage_item.parent_id,
        where: s.organisation_id == ^organisation_id,
        where: s.is_deleted == false,
        where: s.id != ^storage_item.id,
        where: s.name == ^new_name
      )

    case Repo.one(duplicate_check_query) do
      nil -> :ok
      _existing_item -> {:error, :duplicate_name}
    end
  end

  @spec update_storage_item_name(StorageItem.t(), String.t()) ::
          {:ok, StorageItem.t()} | {:error, Ecto.Changeset.t()}
  defp update_storage_item_name(storage_item, new_name) do
    storage_item
    |> StorageItem.changeset(%{
      name: new_name,
      display_name: new_name
    })
    |> Repo.update()
  end

  @spec maybe_update_children_paths(StorageItem.t(), String.t()) :: any()
  defp maybe_update_children_paths(updated_item, organisation_id) do
    if updated_item.mime_type == "inode/directory" do
      Helper.update_children_paths(updated_item, organisation_id)
    end
  end

  @doc """
  Processes index request with various filtering and navigation options.

  Handles parent-based, repository-based, or root-level item listing with
  appropriate breadcrumb navigation.

  ## Examples

      iex> process_index_request(%{"parent_id" => "folder-123"}, user, "org-456")
      {:ok, %{data: [...], breadcrumbs: [...], meta: %{...}}}
  """
  @spec process_index_request(map(), map(), String.t()) :: {:ok, map()} | {:error, String.t()}
  def process_index_request(params, _current_user, organisation_id) do
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

    respond_with_result(result, params, organisation_id)
  end

  @spec build_pagination_opts(map()) :: storage_item_opts()
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

  @spec valid_parent_id?(map()) :: boolean()
  defp valid_parent_id?(%{"parent_id" => parent_id}), do: parent_id != ""
  defp valid_parent_id?(_), do: false

  @spec valid_repository_id?(map()) :: boolean()
  defp valid_repository_id?(%{"repository_id" => repository_id}), do: repository_id != ""
  defp valid_repository_id?(_), do: false

  @spec handle_parent_flow(map(), String.t(), storage_item_opts()) ::
          {:ok, map()} | {:error, atom()}
  defp handle_parent_flow(params, organisation_id, pagination_opts) do
    parent_id = params["parent_id"]

    case get_storage_item_by_org(parent_id, organisation_id) do
      %StorageItem{mime_type: "inode/directory"} ->
        {:ok,
         list_storage_items_with_breadcrumbs(
           parent_id,
           organisation_id,
           pagination_opts
         )}

      %StorageItem{} ->
        {:error, :not_a_directory}

      nil ->
        {:error, "folder not found"}
    end
  end

  @spec handle_repository_flow(map(), String.t(), storage_item_opts()) :: {:ok, map()}
  defp handle_repository_flow(params, organisation_id, pagination_opts) do
    repository_id = params["repository_id"]
    parent_id = Map.get(params, "parent_id")

    items =
      Helper.list_repository_storage_items(
        repository_id,
        parent_id,
        organisation_id,
        pagination_opts
      )

    breadcrumbs =
      if parent_id,
        do: get_storage_item_breadcrumb_navigation(parent_id, organisation_id),
        else: []

    current_folder =
      if parent_id do
        case get_storage_item_by_org(parent_id, organisation_id) do
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

  @spec handle_root_flow(String.t(), storage_item_opts()) :: {:ok, map()}
  defp handle_root_flow(organisation_id, pagination_opts) do
    {:ok, list_storage_items_with_breadcrumbs(nil, organisation_id, pagination_opts)}
  end

  @spec respond_with_result({:ok, map()} | {:error, atom()}, map(), String.t()) ::
          {:ok, map()} | {:error, String.t()}
  defp respond_with_result(
         {:ok, %{items: items, breadcrumbs: breadcrumbs, current_folder: current_folder}},
         params,
         organisation_id
       ) do
    log_success(organisation_id, items, breadcrumbs, current_folder, params)

    {:ok,
     %{
       data: Enum.map(items, &storage_item_data/1),
       breadcrumbs: breadcrumbs,
       current_folder: current_folder,
       meta: build_meta(items, breadcrumbs, params)
     }}
  end

  defp respond_with_result({:error, :not_a_directory}, _params, _org),
    do: {:error, "The specified ID is not a directory"}

  defp respond_with_result({:error, error}, _params, _org),
    do: {:error, error}

  # TODO Move to view file.
  @spec storage_item_data(StorageItem.t(), [StorageAsset.t()]) :: map()
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
      upload_status: storage_item.upload_status,
      inserted_at: storage_item.inserted_at,
      updated_at: storage_item.updated_at,
      assets: Enum.map(storage_assets, &storage_asset_data/1)
    }
  end

  @spec storage_asset_data(StorageAsset.t()) :: map()
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

  @spec parse_integer(String.t() | nil, integer(), integer(), integer() | nil) :: integer()
  defp parse_integer(value, default, min, max) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} when int >= min ->
        if max && int > max, do: max, else: int

      _ ->
        default
    end
  end

  defp parse_integer(_, default, _, _), do: default

  @spec get_folder_name(StorageItem.t()) :: String.t()
  defp get_folder_name(%StorageItem{} = item) do
    item.display_name
    |> fallback(item.name)
    |> fallback(item.path && extract_name_from_path(item.path))
    |> fallback(item.materialized_path && extract_name_from_path(item.materialized_path))
    |> default_if_blank("Unnamed Folder")
  end

  @spec fallback(String.t() | nil, String.t() | nil) :: String.t() | nil
  defp fallback(nil, fallback), do: fallback
  defp fallback("", fallback), do: fallback
  defp fallback(value, _fallback), do: value

  @spec default_if_blank(String.t() | nil, String.t()) :: String.t()
  defp default_if_blank(nil, default), do: default
  defp default_if_blank("", default), do: default
  defp default_if_blank(value, _default), do: value

  @spec extract_name_from_path(String.t() | nil) :: String.t()
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

  # TODO - verify logging cases
  @spec log_success(String.t(), [StorageItem.t()], [breadcrumb_item()], map() | nil, map()) :: :ok
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

  @spec build_meta([StorageItem.t()], [breadcrumb_item()], map()) :: map()
  defp build_meta(items, breadcrumbs, params) do
    %{
      count: length(items),
      breadcrumbs_count: length(breadcrumbs),
      sort_by: Map.get(params, "sort_by"),
      sort_order: Map.get(params, "sort_order"),
      timestamp: DateTime.utc_now()
    }
  end

  @doc """
  Validates a UUID parameter in the given map.

  Returns `:ok` if the parameter is valid, or `{:error, String.t()}` if it is invalid.

  ## Examples

      iex> validate_uuid_param(%{"parent_id" => "550e8400-e29b-41d4-a716-446655440000"}, "parent_id")
      :ok

      iex> validate_uuid_param(%{"parent_id" => "invalid-uuid"}, "parent_id")
      {:error, "Invalid UUID format for parent_id"}

      iex> validate_uuid_param(%{}, "parent_id")
      :ok
  """
  @spec validate_uuid_param(map(), String.t()) :: :ok | {:error, String.t()}
  def validate_uuid_param(params, key) do
    case Map.get(params, key) do
      nil ->
        :ok

      "" ->
        :ok

      value ->
        case Ecto.UUID.cast(value) do
          {:ok, _} -> :ok
          :error -> {:error, "Invalid UUID format for #{key}"}
        end
    end
  end

  @doc """
  Handles navigation request for storage items with breadcrumb data.

  ## Examples

      iex> handle_navigation("parent-123", "org-456", %{"limit" => "20"})
      {:ok, %{data: %{items: [...], breadcrumbs: [...]}, meta: %{...}}}
  """
  @spec handle_navigation(String.t() | nil, String.t(), map()) :: {:ok, navigation_response()}
  def handle_navigation(parent_id, organisation_id, params) do
    pagination_opts = build_pagination_opts(params)

    navigation_data =
      Helper.get_storage_navigation_data(parent_id, organisation_id, pagination_opts)

    log_navigation_retrieved(organisation_id, parent_id, navigation_data)

    response = build_navigation_response(navigation_data)

    {:ok, response}
  end

  # TODO - verify logging cases
  @spec log_navigation_retrieved(String.t(), String.t() | nil, map()) :: :ok
  defp log_navigation_retrieved(organisation_id, parent_id, navigation_data) do
    Logger.info("Storage navigation data retrieved", %{
      organisation_id: organisation_id,
      parent_id: parent_id,
      items_count: length(navigation_data.items),
      breadcrumbs_count: length(navigation_data.breadcrumbs)
    })
  end

  @spec build_navigation_response(map()) :: navigation_response()
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

  @doc """
  Calculates the depth level of a storage item based on its path.

  The depth level represents how deep an item is in the folder hierarchy:
  - Root level items have depth 1
  - Items in subfolders have incrementally higher depths

  ## Examples

      iex> calculate_depth_level("/Documents/Contracts/Q4/August")
      4

      iex> calculate_depth_level("/Documents")
      1

      iex> calculate_depth_level("/")
      0

      iex> calculate_depth_level("")
      0
  """
  @spec calculate_depth_level(String.t()) :: non_neg_integer()
  def calculate_depth_level(path) when is_binary(path) do
    path
    |> String.trim("/")
    |> String.split("/")
    |> Enum.reject(&(&1 == ""))
    |> length()
  end
end
