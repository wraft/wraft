defmodule WraftDoc.Storage.StorageItems do
  @moduledoc """
  Storage items management - handles CRUD operations, navigation, and organization
  of storage items including files and folders.
  """
  require Logger
  import Ecto.Query, warn: false
  alias WraftDoc.Repo
  alias WraftDoc.Storage, as: Helper
  alias WraftDoc.Storage.StorageAsset
  alias WraftDoc.Storage.StorageAssets
  alias WraftDoc.Storage.StorageItem

  @doc """
  Returns the list of storage items.
  """
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

  @doc """
  Gets a single storage_item.
  """
  def get_storage_item!(id), do: Repo.get!(StorageItem, id)

  def create_storage_item(attrs \\ %{}) do
    attrs = Helper.handle_duplicate_names(attrs)

    case %StorageItem{}
         |> StorageItem.changeset(attrs)
         |> Repo.insert() do
      {:ok, storage_item} ->
        {:ok, storage_item}

      {:error, changeset} ->
        if duplicate_external_id_error?(changeset) do
          # Handle duplicate gracefully
          get_existing_storage_item(attrs)
        else
          # Return other errors normally
          {:error, changeset}
        end
    end
  end

  defp duplicate_external_id_error?(%Ecto.Changeset{errors: errors}) do
    case Keyword.get(errors, :external_id) do
      {"has already been taken", opts} ->
        Keyword.get(opts, :constraint_name) == "storage_items_external_id_sync_source_index"

      _ ->
        false
    end
  end

  defp get_existing_storage_item(%{"external_id" => ext_id, "sync_source" => sync} = _attrs)
       when not is_nil(ext_id) and not is_nil(sync) do
    case Repo.get_by(StorageItem, external_id: ext_id, sync_source: sync) do
      nil -> {:error, :not_found}
      existing -> {:ok, existing}
    end
  end

  defp get_existing_storage_item(_), do: {:ok, :invalid_lookup_keys}

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
    item_id
    |> get_storage_item_breadcrumbs(organisation_id)
    |> Enum.map(&map_breadcrumb_item/1)
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

  def change_storage_item(%StorageItem{} = storage_item, attrs \\ %{}),
    do: StorageItem.changeset(storage_item, attrs)

  defp now_utc, do: DateTime.utc_now()

  def soft_delete_storage_item(%StorageItem{} = storage_item),
    do: Repo.transaction(fn -> perform_soft_delete(storage_item) end)

  defp perform_soft_delete(%StorageItem{} = storage_item) do
    maybe_soft_delete_children(storage_item, now_utc())
    soft_delete_item(storage_item, now_utc())
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
    parent_id
    |> fetch_immediate_children()
    |> Enum.flat_map(fn child ->
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
    with :ok <- validate_name(new_name),
         :ok <- check_duplicate_name(storage_item, new_name, organisation_id),
         {:ok, updated_item} <- update_storage_item_name(storage_item, new_name) do
      maybe_update_children_paths(updated_item, organisation_id)
      {:ok, updated_item}
    end
  end

  defp validate_name(name) do
    if String.contains?(name, "/") do
      {:error, :invalid_name}
    else
      :ok
    end
  end

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

  defp update_storage_item_name(storage_item, new_name) do
    changeset =
      StorageItem.changeset(storage_item, %{
        name: new_name,
        display_name: new_name
      })

    Repo.update(changeset)
  end

  defp maybe_update_children_paths(updated_item, organisation_id) do
    if updated_item.mime_type == "inode/directory" do
      Helper.update_children_paths(updated_item, organisation_id)
    end
  end

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

    case get_storage_item_by_org(parent_id, organisation_id) do
      %StorageItem{mime_type: "inode/directory"} ->
        Logger.info("✅ Folder found, listing contents", %{parent_id: parent_id})

        {:ok,
         list_storage_items_with_breadcrumbs(
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

  defp handle_root_flow(organisation_id, pagination_opts) do
    Logger.info("🏠 Fetching root level items", %{organisation_id: organisation_id})
    {:ok, list_storage_items_with_breadcrumbs(nil, organisation_id, pagination_opts)}
  end

  # BUILD RESPONSE
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

  defp respond_with_result({:error, :folder_not_found}, _params, _org),
    do: {:error, "Folder not found"}

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

  @doc """
  Validates a UUID parameter in the given map.

  Returns `:ok` if the parameter is valid, or `{:error, String.t()}` if it is invalid.
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

  def handle_navigation(parent_id, organisation_id, params) do
    pagination_opts = build_pagination_opts(params)

    navigation_data =
      Helper.get_storage_navigation_data(parent_id, organisation_id, pagination_opts)

    log_navigation_retrieved(organisation_id, parent_id, navigation_data)

    response = build_navigation_response(navigation_data)

    {:ok, response}
  end

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
end
