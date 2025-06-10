defmodule WraftDoc.Storage do
  @moduledoc """
  The sync job model.
  """
  import Ecto.Query, warn: false
  require Logger

  alias WraftDoc.Repo
  alias WraftDoc.Storage.Repository
  alias WraftDoc.Storage.StorageAcessLogs
  alias WraftDoc.Storage.StorageAsset
  alias WraftDoc.Storage.StorageAssets
  alias WraftDoc.Storage.StorageItem
  alias WraftDoc.Storage.StorageItems

  def list_repositories do
    Repo.all(Repository)
  end

  def get_latest_repository(organisation_id) do
    Repository
    |> where([r], r.organisation_id == ^organisation_id)
    |> order_by([r], desc: r.inserted_at)
    |> limit(1)
    |> Repo.one()
  end

  def get_repository!(id), do: Repo.get!(Repository, id)

  def create_repository(attrs \\ %{}) do
    %Repository{}
    |> Repository.changeset(attrs)
    |> Repo.insert()
  end

  def update_repository(%Repository{} = repository, attrs) do
    repository
    |> Repository.changeset(attrs)
    |> Repo.update()
  end

  def delete_repository(%Repository{} = repository) do
    Repo.delete(repository)
  end

  def change_repository(%Repository{} = repository, attrs \\ %{}) do
    Repository.changeset(repository, attrs)
  end

  @doc false
  def handle_duplicate_names(%{"parent_id" => parent_id, "name" => name} = attrs)
      when is_binary(parent_id) and is_binary(name) do
    {base_name, extension} = split_name_and_extension(name)

    similar_names =
      StorageItem
      |> where([s], s.parent_id == ^parent_id and s.is_deleted == false)
      |> where([s], like(s.name, ^"#{base_name}%#{extension}"))
      |> select([s], s.name)
      |> Repo.all()

    case similar_names do
      [] ->
        attrs

      _ ->
        next_number = find_next_available_number(similar_names, base_name, extension)
        updated_name = "#{base_name}_#{next_number}#{extension}"
        Map.put(attrs, "name", updated_name)
    end
  end

  def handle_duplicate_names(attrs), do: attrs

  # Utility: more robust name splitting
  defp split_name_and_extension(name) do
    extension = Path.extname(name)
    base_name = Path.rootname(name)
    {base_name, extension}
  end

  @doc false
  def find_next_available_number(similar_names, base_name, extension) do
    # Extract numbers from existing names
    numbers =
      Enum.map(similar_names, fn name ->
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

  def schedule_folder_deletion(folder_id) do
    %{folder_id: folder_id}
    |> WraftDoc.Workers.StorageDeletionWorker.new()
    |> Oban.insert()
  end

  def get_meaningful_name(%StorageItem{} = item) do
    item
    |> extract_first_non_empty([
      & &1.display_name,
      & &1.name,
      fn i -> extract_name_from_path(i.path) end,
      fn i -> extract_name_from_path(i.materialized_path) end
    ])
    |> case do
      nil -> "Unnamed Folder"
      name -> name
    end
  end

  defp extract_first_non_empty(item, extractors) do
    Enum.find_value(extractors, fn extractor ->
      value = safe_trim(extractor.(item))
      if value != "", do: value, else: nil
    end)
  end

  defp safe_trim(nil), do: nil
  defp safe_trim(value), do: String.trim(value)

  # Helper function to extract the last segment from a path
  def extract_name_from_path(path) when is_binary(path) do
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

  def extract_name_from_path(_), do: "Unknown"

  def get_storage_navigation_data(folder_id \\ nil, organisation_id, opts \\ []) do
    # Get the current folder's items
    items = StorageItems.list_storage_items(folder_id, organisation_id, opts)

    # Get breadcrumb navigation
    breadcrumbs =
      if folder_id do
        StorageItems.get_storage_item_breadcrumb_navigation(folder_id, organisation_id)
      else
        # For root level, return empty breadcrumbs or a root breadcrumb
        []
      end

    %{
      items: items,
      breadcrumbs: breadcrumbs
    }
  end

  # Get breadcrumbs for ancestors only (excluding the current item)
  def get_ancestors_breadcrumbs(%StorageItem{parent_id: nil} = current_item, organisation_id) do
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

  def get_ancestors_breadcrumbs(
        %StorageItem{parent_id: parent_id} = current_item,
        organisation_id
      )
      when not is_nil(parent_id) do
    require Logger

    Logger.info("🔍 Building breadcrumbs for item with parent_id", %{
      id: current_item.id,
      parent_id: parent_id,
      path: current_item.path,
      materialized_path: current_item.materialized_path
    })

    # Try to get breadcrumbs using parent_id relationships first
    case StorageItems.get_storage_item_by_org(parent_id, organisation_id) do
      nil ->
        Logger.info("⚠️ Parent not found by parent_id, trying path-based breadcrumbs")
        # If parent_id doesn't point to an existing record, try to build from path
        build_breadcrumbs_from_path(current_item, organisation_id)

      parent ->
        Logger.info("✅ Found parent, building breadcrumbs from parent_id relationships")
        # Build using parent_id relationships
        build = build_storage_ancestors(parent, organisation_id, [])

        Enum.map(build, fn item ->
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

  def build_breadcrumbs_from_path(%StorageItem{} = current_item, organisation_id) do
    path = current_item.materialized_path || current_item.path

    case extract_path_segments(path) do
      {:ok, segments} ->
        segments
        # Remove current folder from breadcrumbs
        |> Enum.drop(-1)
        |> Enum.with_index()
        |> Enum.map(&build_breadcrumb(&1, segments, organisation_id))

      :empty_path ->
        []
    end
  end

  defp extract_path_segments(path) do
    if path && String.trim(path) != "" do
      segments =
        path
        |> String.trim()
        |> String.trim_leading("/")
        |> String.trim_trailing("/")
        |> String.split("/")
        |> Enum.reject(&(&1 == "" or is_nil(&1)))

      {:ok, segments}
    else
      :empty_path
    end
  end

  defp build_breadcrumb({segment, index}, segments, organisation_id) do
    segment_path = "/" <> Enum.join(Enum.take(segments, index + 1), "/")

    case StorageItems.find_storage_item_by_path(segment_path, organisation_id) do
      %StorageItem{} = item -> build_real_breadcrumb(item)
      nil -> build_virtual_breadcrumb(segment, segment_path)
    end
  end

  defp build_real_breadcrumb(item) do
    %{
      id: item.id,
      name: get_meaningful_name(item),
      is_folder: item.mime_type == "inode/directory",
      path: item.path,
      materialized_path: item.materialized_path
    }
  end

  defp build_virtual_breadcrumb(segment, segment_path) do
    %{
      id: nil,
      name: segment,
      is_folder: true,
      path: segment_path,
      materialized_path: segment_path
    }
  end

  # Builds the list of ancestors recursively, starting from the current item
  def build_storage_ancestors(%StorageItem{parent_id: nil} = item, _organisation_id, acc),
    do: [item | acc]

  def build_storage_ancestors(%StorageItem{parent_id: parent_id} = item, organisation_id, acc) do
    case StorageItems.get_storage_item_by_org(parent_id, organisation_id) do
      nil -> [item | acc]
      parent -> build_storage_ancestors(parent, organisation_id, [item | acc])
    end
  end

  def list_repository_storage_items(repository_id, parent_id \\ nil, organisation_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)
    offset = Keyword.get(opts, :offset, 0)
    sort_by = Keyword.get(opts, :sort_by, "created")
    sort_order = Keyword.get(opts, :sort_order, "desc")

    # Parse sorting options
    order_by_clause = parse_sort_options(sort_by, sort_order)

    query =
      from(s in StorageItem,
        where: s.repository_id == ^repository_id,
        where: s.organisation_id == ^organisation_id,
        where: s.is_deleted == false,
        order_by: ^order_by_clause,
        limit: ^limit,
        offset: ^offset
      )

    query =
      if parent_id do
        from(s in query, where: s.parent_id == ^parent_id)
      else
        # For root level items in repository, filter by parent_id being nil AND depth_level = 1
        from(s in query,
          where: is_nil(s.parent_id) and s.depth_level == 1
        )
      end

    Repo.all(query)
  end

  # Helper function to parse sort options
  def parse_sort_options(sort_by, sort_order) do
    direction = parse_sort_direction(sort_order)
    parse_sort_field(sort_by, direction)
  end

  defp parse_sort_direction(sort_order) do
    case String.downcase(sort_order || "") do
      "asc" -> :asc
      "desc" -> :desc
      _ -> :desc
    end
  end

  defp parse_sort_field(sort_by, direction) do
    case String.downcase(sort_by || "") do
      "name" -> [{:asc, :item_type}, {direction, :name}]
      "updated" -> [{direction, :updated_at}]
      "created" -> [{direction, :inserted_at}]
      "size" -> [{:asc, :item_type}, {direction, :size}]
      "type" -> [{:asc, :item_type}, {direction, :file_extension}]
      _ -> [{:desc, :inserted_at}]
    end
  end

  # Prepares and validates upload parameters
  def prepare_upload_params(
        %{"file" => %Plug.Upload{} = upload} = params,
        current_user,
        organisation_id
      ) do
    require Logger

    Logger.info("📁 Preparing upload parameters", %{
      filename: upload.filename,
      size: upload.path |> File.stat!() |> Map.get(:size),
      organisation_id: organisation_id
    })

    with {:ok, file_metadata} <- extract_file_metadata(upload),
         {:ok, storage_item_params} <-
           StorageItems.build_storage_item_params(
             params,
             file_metadata,
             current_user,
             organisation_id
           ),
         {:ok, storage_asset_params} <-
           StorageAssets.build_storage_asset_params(
             params,
             file_metadata,
             upload,
             current_user,
             organisation_id
           ) do
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

  def prepare_upload_params(_params, _current_user, _organisation_id) do
    Logger.error("❌ No file provided in upload parameters")
    {:error, "File upload is required"}
  end

  # Extracts metadata from uploaded file
  def extract_file_metadata(%Plug.Upload{} = upload) do
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

  # Executes the complete upload transaction
  def execute_upload_transaction(enriched_params) do
    require Logger
    Logger.info("🔄 Starting upload transaction")

    Ecto.Multi.new()
    |> Ecto.Multi.insert(
      :storage_item,
      StorageItem.changeset(%StorageItem{}, enriched_params.storage_item)
    )
    |> Ecto.Multi.insert(:storage_asset, fn %{storage_item: storage_item} ->
      storage_asset_params =
        Map.put(enriched_params.storage_asset, :storage_item_id, storage_item.id)

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
    |> Ecto.Multi.run(:create_access_log, fn _repo,
                                             %{
                                               storage_item: storage_item,
                                               complete_upload: storage_asset
                                             } ->
      StorageAcessLogs.create_upload_access_log(storage_item, storage_asset, enriched_params)
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
  def calculate_item_hierarchy(nil, _organisation_id, _filename) do
    # Root level item
    {1, "/"}
  end

  def calculate_item_hierarchy(parent_id, organisation_id, filename) do
    case StorageItems.get_storage_item_by_org(parent_id, organisation_id) do
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
  def calculate_file_checksum(file_path) do
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

  # Schedules background processing for uploaded file
  def schedule_background_processing(storage_asset, storage_item) do
    Task.start(fn ->
      require Logger

      Logger.info("🔄 Starting background processing", %{
        storage_asset_id: storage_asset.id,
        storage_item_id: storage_item.id
      })

      # Update processing status
      StorageAssets.update_storage_asset(storage_asset, %{processing_status: "processing"})

      # Perform background tasks
      with :ok <- extract_content_if_supported(storage_item),
           :ok <- generate_thumbnail_if_supported(storage_item) do
        # Update storage item with processing results
        StorageItems.update_storage_item(storage_item, %{
          content_extracted: true,
          thumbnail_generated: true
        })

        # Update asset processing status
        StorageAssets.update_storage_asset(storage_asset, %{processing_status: "completed"})

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

          StorageAssets.update_storage_asset(storage_asset, %{processing_status: "failed"})
      end
    end)
  end

  # Extracts content from supported file types
  def extract_content_if_supported(%StorageItem{mime_type: "application/pdf"}), do: :ok
  def extract_content_if_supported(%StorageItem{mime_type: "text/" <> _}), do: :ok
  def extract_content_if_supported(_), do: :ok

  # Generates thumbnails for supported file types
  def generate_thumbnail_if_supported(%StorageItem{mime_type: "image/" <> _}), do: :ok
  def generate_thumbnail_if_supported(%StorageItem{mime_type: "application/pdf"}), do: :ok
  def generate_thumbnail_if_supported(_), do: :ok

  # Helper function to update materialized paths of all children when a folder is renamed
  def update_children_paths(%StorageItem{} = parent_item, _organisation_id) do
    # Get all children recursively
    children = StorageItems.get_all_children_storage_items(parent_item.id)

    # Update each child's materialized path
    Enum.each(children, fn child ->
      new_materialized_path =
        String.replace(
          child.materialized_path,
          parent_item.materialized_path,
          Path.join(parent_item.materialized_path, parent_item.name)
        )

      path = StorageItem.changeset(child, %{materialized_path: new_materialized_path})
      Repo.update(path)
    end)
  end
end
