defmodule WraftDoc.Storage.StorageItems do
  @moduledoc """
  Storage items management - handles CRUD operations, navigation, and organization
  of storage items including files and folders.
  """

  import Ecto.Query, warn: false
  alias WraftDoc.Repo
  alias WraftDoc.Storage, as: Helper
  alias WraftDoc.Storage.StorageAssets
  alias WraftDoc.Storage.StorageItem

  def list_storage_items(parent_id \\ nil, organisation_id \\ nil, opts \\ [])

  def list_storage_items(nil, nil, _opts) do
    # Legacy behavior - return all items (you might want to restrict this)``1d
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
        # For root level items, filter by both parent_id being nil AND depth_level = 1
        from(s in base_query,
          where: is_nil(s.parent_id) and s.depth_level == 1
        )
      end

    Repo.all(query)
  end

  def list_storage_items(parent_id, organisation_id, opts) do
    list_storage_items(parent_id, to_string(organisation_id), opts)
  end

  def get_storage_item!(id), do: Repo.get!(StorageItem, id)

  def create_storage_item(attrs \\ %{}) do
    attrs = Helper.handle_duplicate_names(attrs)

    %StorageItem{}
    |> StorageItem.changeset(attrs)
    |> Repo.insert()
  end

  def update_storage_item(%StorageItem{} = storage_item, attrs) do
    storage_item
    |> StorageItem.changeset(attrs)
    |> Repo.update()
  end

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
        Helper.schedule_folder_deletion(storage_item.id)
      end

      # Schedule asset deletion
      StorageAssets.schedule_asset_deletion(storage_item.id)
    end)
  end

  def get_storage_item_breadcrumbs(item_id, organisation_id) do
    case get_storage_item_by_org(item_id, organisation_id) do
      nil -> []
      item -> Helper.build_storage_ancestors(item, organisation_id, [])
    end
  end

  def get_storage_item_breadcrumb_navigation(item_id, organisation_id) do
    breadcrumbs = get_storage_item_breadcrumbs(item_id, organisation_id)

    Enum.map(breadcrumbs, &map_breadcrumb_item/1)
  end

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

  def change_storage_item(%StorageItem{} = storage_item, attrs \\ %{}) do
    StorageItem.changeset(storage_item, attrs)
  end

  defp now_utc, do: DateTime.utc_now()

  def soft_delete_storage_item(%StorageItem{} = storage_item) do
    Repo.transaction(fn -> perform_soft_delete(storage_item) end)
  end

  defp perform_soft_delete(%StorageItem{} = storage_item) do
    now = now_utc()

    maybe_soft_delete_children(storage_item, now)
    soft_delete_item(storage_item, now)
  end

  defp maybe_soft_delete_children(%StorageItem{mime_type: "inode/directory", id: id}, now) do
    children = get_all_children_storage_items(id)

    unless Enum.empty?(children) do
      child_ids = Enum.map(children, & &1.id)

      q = from(s in StorageItem, where: s.id in ^child_ids)
      Repo.update_all(q, set: [is_deleted: true, deleted_at: now])
    end
  end

  defp maybe_soft_delete_children(_storage_item, _now), do: :ok

  defp soft_delete_item(storage_item, now) do
    storage_item
    |> StorageItem.changeset(%{is_deleted: true, deleted_at: now})
    |> Repo.update()
  end

  # Gets all children of a storage item recursively (for folders).
  def get_all_children_storage_items(parent_id) do
    children = fetch_immediate_children(parent_id)

    Enum.flat_map(children, fn child ->
      process_child(child)
    end)
  end

  defp fetch_immediate_children(parent_id) do
    fetch =
      from(s in StorageItem,
        where: s.parent_id == ^parent_id and s.is_deleted == false
      )

    Repo.all(fetch)
  end

  defp process_child(%StorageItem{mime_type: "inode/directory", id: id} = child) do
    [child | get_all_children_storage_items(id)]
  end

  defp process_child(child), do: [child]

  def list_storage_items_with_breadcrumbs(parent_id \\ nil, organisation_id, opts \\ []) do
    items = list_storage_items(parent_id, organisation_id, opts)
    {breadcrumbs, current_folder} = build_breadcrumbs_and_folder(parent_id, organisation_id)

    %{
      items: items,
      breadcrumbs: breadcrumbs,
      current_folder: current_folder
    }
  end

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

  # Helper to find storage item by path
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

  def list_storage_items_by_parent(parent_id, organisation_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)
    offset = Keyword.get(opts, :offset, 0)
    sort_by = Keyword.get(opts, :sort_by, "created")
    sort_order = Keyword.get(opts, :sort_order, "desc")

    # Parse sorting options
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

  def get_storage_item_by_org!(id, organisation_id) do
    query =
      from(s in StorageItem,
        where: s.id == ^id,
        where: s.organisation_id == ^organisation_id,
        where: s.is_deleted == false
      )

    Repo.one!(query)
  end

  def get_storage_item_by_org(id, organisation_id) do
    query =
      from(s in StorageItem,
        where: s.id == ^id,
        where: s.organisation_id == ^organisation_id,
        where: s.is_deleted == false
      )

    Repo.one(query)
  end

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

  def get_storage_item_stats(parent_id, organisation_id) do
    base_query = build_base_query(organisation_id)
    scoped_query = apply_parent_scope(base_query, parent_id)
    stats_query = build_stats_query(scoped_query)
    stats_result = Repo.one(stats_query)

    normalize_stats(stats_result)
  end

  defp build_base_query(organisation_id) do
    from(s in StorageItem,
      where: s.organisation_id == ^organisation_id,
      where: s.is_deleted == false
    )
  end

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

  def search_storage_items(search_term, organisation_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    offset = Keyword.get(opts, :offset, 0)
    item_type_filter = Keyword.get(opts, :item_type)
    sort_by = Keyword.get(opts, :sort_by, "created")
    sort_order = Keyword.get(opts, :sort_order, "desc")

    # Parse sorting options
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
  """
  def create_storage_asset_with_item_public(params, organisation_id) do
    with {:ok, enriched_params} <- Helper.prepare_upload_params(params, nil, organisation_id),
         {:ok, result} <- Helper.execute_upload_transaction(enriched_params) do
      {:ok, result}
    else
      {:error, error} -> {:error, error}
    end
  end

  def build_storage_item_params(params, file_metadata, current_user, organisation_id) do
    parent_id = Map.get(params, "parent_id")
    repository_id = Map.get(params, "repository_id")

    # Calculate depth level and materialized path
    {depth_level, materialized_path} =
      Helper.calculate_item_hierarchy(parent_id, organisation_id, file_metadata.filename)

    base_name = Path.basename(file_metadata.filename, file_metadata.file_extension)
    display_name = Map.get(params, "display_name", file_metadata.filename)

    storage_item_params = %{
      name: base_name,
      display_name: display_name,
      item_type: "file",
      path: "/#{file_metadata.filename}",
      path_hash: Base.encode16(:crypto.hash(:sha256, file_metadata.filename), case: :lower),
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

  def rename_storage_item(%StorageItem{} = storage_item, new_name, organisation_id) do
    # Validate the new name
    if String.contains?(new_name, "/") do
      {:error, :invalid_name}
    else
      # Get the parent folder to check for duplicates
      parent_id = storage_item.parent_id

      # Check for duplicate names in the same folder
      duplicate_check_query =
        from(s in StorageItem,
          where: s.parent_id == ^parent_id,
          where: s.organisation_id == ^organisation_id,
          where: s.is_deleted == false,
          where: s.id != ^storage_item.id,
          where: s.name == ^new_name
        )

      case Repo.one(duplicate_check_query) do
        nil ->
          # No duplicate found, proceed with rename
          changeset =
            StorageItem.changeset(storage_item, %{
              name: new_name,
              display_name: new_name
            })

          case Repo.update(changeset) do
            {:ok, updated_item} ->
              # If it's a folder, update the materialized paths of all children
              if updated_item.mime_type == "inode/directory" do
                Helper.update_children_paths(updated_item, organisation_id)
              end

              {:ok, updated_item}

            {:error, changeset} ->
              {:error, changeset}
          end

        _existing_item ->
          {:error, :duplicate_name}
      end
    end
  end
end
