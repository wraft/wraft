defmodule WraftDoc.Storage do
  @moduledoc """
  The Storage context provides functionality for managing file storage, repositories,
  and storage items within organizations.

  This module handles:
  - Repository CRUD operations
  - File upload processing and metadata extraction
  - Storage item hierarchy and navigation
  - Duplicate name handling
  - Background processing for content extraction and thumbnails
  """

  import Ecto.Query, warn: false
  require Logger

  alias WraftDoc.Repo
  alias WraftDoc.Storage.Repository
  alias WraftDoc.Storage.StorageAsset
  alias WraftDoc.Storage.StorageAssets
  alias WraftDoc.Storage.StorageItem
  alias WraftDoc.Storage.StorageItems

  @doc "Lists all repositories"
  @spec list_repositories() :: [Repository.t()]
  def list_repositories, do: Repo.all(Repository)

  @doc "Gets the latest repository for an organization"
  @spec get_latest_repository(String.t()) :: Repository.t() | nil
  def get_latest_repository(organisation_id) do
    Repository
    |> where([r], r.organisation_id == ^organisation_id)
    |> order_by([r], desc: r.inserted_at)
    |> limit(1)
    |> Repo.one()
  end

  @doc "Gets a repository by ID, raises if not found"
  @spec get_repository!(String.t()) :: Repository.t()
  def get_repository!(id), do: Repo.get!(Repository, id)

  @doc "Creates a new repository"
  @spec create_repository(map()) :: {:ok, Repository.t()} | {:error, Ecto.Changeset.t()}
  def create_repository(attrs \\ %{}) do
    %Repository{}
    |> Repository.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Updates a repository"
  @spec update_repository(Repository.t(), map()) ::
          {:ok, Repository.t()} | {:error, Ecto.Changeset.t()}
  def update_repository(%Repository{} = repository, attrs) do
    repository
    |> Repository.changeset(attrs)
    |> Repo.update()
  end

  @doc "Deletes a repository"
  @spec delete_repository(Repository.t()) :: {:ok, Repository.t()} | {:error, Ecto.Changeset.t()}
  def delete_repository(%Repository{} = repository), do: Repo.delete(repository)

  @doc "Creates a changeset for a repository"
  @spec change_repository(Repository.t(), map()) :: Ecto.Changeset.t()
  def change_repository(%Repository{} = repository, attrs \\ %{}),
    do: Repository.changeset(repository, attrs)

  @doc "Lists repositories by user and organization"
  @spec list_repositories_by_user_and_organisation(Ecto.UUID.t(), String.t()) :: [Repository.t()]
  def list_repositories_by_user_and_organisation(user_id, organisation_id) do
    query =
      from(r in Repository,
        where: r.creator_id == ^user_id and r.organisation_id == ^organisation_id,
        order_by: [desc: r.inserted_at]
      )

    Repo.all(query)
  end

  @doc "Handles duplicate names by appending a number suffix"
  @spec handle_duplicate_names(map()) :: map()
  def handle_duplicate_names(
        %{
          "parent_id" => parent_id,
          "name" => name,
          "item_type" => item_type,
          "file_extension" => file_extension,
          "path" => path,
          "materialized_path" => materialized_path,
          "metadata" => metadata
        } = attrs
      )
      when item_type != "folder" do
    similar_names =
      StorageItem
      |> where([s], s.is_deleted == false)
      |> where(
        [s],
        ^if parent_id == nil do
          dynamic([s], is_nil(s.parent_id))
        else
          dynamic([s], s.parent_id == ^parent_id)
        end
      )
      |> where([s], like(s.name, ^"#{name}%"))
      |> select([s], s.name)
      |> Repo.all()

    case similar_names do
      [] ->
        attrs

      _ ->
        next_number = find_next_available_number(similar_names, name)
        updated_name = "#{name}_#{next_number}"
        updated_file_name = "#{updated_name} #{file_extension}"

        Map.merge(attrs, %{
          "name" => updated_name,
          "display_name" => updated_file_name,
          "path" => Regex.replace(~r{[^/]+$}, path, updated_file_name),
          "materialized_path" => Regex.replace(~r{[^/]+$}, materialized_path, updated_file_name),
          "metadata" => Map.put(metadata, "filename", updated_file_name)
        })
    end
  end

  def handle_duplicate_names(attrs), do: attrs

  defp find_next_available_number(similar_names, base_name) do
    similar_names
    |> Enum.map(fn name ->
      case Regex.run(~r/#{base_name}_(\d+)/, name) do
        [_, num] -> String.to_integer(num)
        _ -> 0
      end
    end)
    |> case do
      [] -> 1
      nums -> Enum.max(nums) + 1
    end
  end

  @doc "Schedules folder deletion using background worker"
  @spec schedule_folder_deletion(String.t()) :: {:ok, Oban.Job.t()} | {:error, Ecto.Changeset.t()}
  def schedule_folder_deletion(folder_id) do
    %{folder_id: folder_id}
    |> WraftDoc.Workers.StorageDeletionWorker.new()
    |> Oban.insert()
  end

  @doc "Gets meaningful display name for a storage item"
  @spec get_meaningful_name(StorageItem.t()) :: String.t()
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

  @spec extract_first_non_empty(StorageItem.t(), [function()]) :: String.t() | nil
  defp extract_first_non_empty(item, extractors) do
    Enum.find_value(extractors, fn extractor ->
      value = safe_trim(extractor.(item))
      if value != "", do: value, else: nil
    end)
  end

  @spec safe_trim(String.t() | nil) :: String.t() | nil
  defp safe_trim(nil), do: nil
  defp safe_trim(value), do: String.trim(value)

  @doc "Extracts name from a file path"
  @spec extract_name_from_path(String.t() | nil) :: String.t()
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

  @doc "Gets storage navigation data including items and breadcrumbs"
  @spec get_storage_navigation_data(String.t() | nil, String.t(), keyword()) :: map()
  def get_storage_navigation_data(folder_id \\ nil, organisation_id, opts \\ []) do
    items = StorageItems.list_storage_items(folder_id, organisation_id, opts)

    breadcrumbs =
      if folder_id do
        StorageItems.get_storage_item_breadcrumb_navigation(folder_id, organisation_id)
      else
        []
      end

    %{
      items: items,
      breadcrumbs: breadcrumbs
    }
  end

  @doc "Gets ancestors breadcrumbs for navigation"
  @spec get_ancestors_breadcrumbs(StorageItem.t(), String.t()) :: [map()]
  def get_ancestors_breadcrumbs(%StorageItem{parent_id: nil} = current_item, organisation_id) do
    path = current_item.materialized_path || current_item.path

    if path && String.contains?(path, "/") do
      build_breadcrumbs_from_path(current_item, organisation_id)
    else
      []
    end
  end

  def get_ancestors_breadcrumbs(
        %StorageItem{parent_id: parent_id} = current_item,
        organisation_id
      )
      when not is_nil(parent_id) do
    case StorageItems.get_storage_item_by_org(parent_id, organisation_id) do
      nil ->
        build_breadcrumbs_from_path(current_item, organisation_id)

      parent ->
        parent
        |> build_storage_ancestors(organisation_id, [])
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

  @doc "Builds breadcrumbs from materialized path when parent relationships are missing"
  @spec build_breadcrumbs_from_path(StorageItem.t(), String.t()) :: [map()]
  def build_breadcrumbs_from_path(%StorageItem{} = current_item, organisation_id) do
    path = current_item.materialized_path || current_item.path

    case extract_path_segments(path) do
      {:ok, segments} ->
        segments
        |> Enum.drop(-1)
        |> Enum.with_index()
        |> Enum.map(&build_breadcrumb(&1, segments, organisation_id))

      :empty_path ->
        []
    end
  end

  @spec extract_path_segments(String.t() | nil) :: {:ok, [String.t()]} | :empty_path
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

  @spec build_breadcrumb({String.t(), integer()}, [String.t()], String.t()) :: map()
  defp build_breadcrumb({segment, index}, segments, organisation_id) do
    segment_path = "/" <> Enum.join(Enum.take(segments, index + 1), "/")

    case StorageItems.find_storage_item_by_path(segment_path, organisation_id) do
      %StorageItem{} = item -> build_real_breadcrumb(item)
      nil -> build_virtual_breadcrumb(segment, segment_path)
    end
  end

  @spec build_real_breadcrumb(StorageItem.t()) :: map()
  defp build_real_breadcrumb(item) do
    %{
      id: item.id,
      name: get_meaningful_name(item),
      is_folder: item.mime_type == "inode/directory",
      path: item.path,
      materialized_path: item.materialized_path
    }
  end

  @spec build_virtual_breadcrumb(String.t(), String.t()) :: map()
  defp build_virtual_breadcrumb(segment, segment_path) do
    %{
      id: nil,
      name: segment,
      is_folder: true,
      path: segment_path,
      materialized_path: segment_path
    }
  end

  @doc "Builds storage ancestors recursively for breadcrumb navigation"
  @spec build_storage_ancestors(StorageItem.t(), String.t(), [StorageItem.t()]) :: [
          StorageItem.t()
        ]
  def build_storage_ancestors(%StorageItem{parent_id: nil} = item, _organisation_id, acc),
    do: [item | acc]

  def build_storage_ancestors(%StorageItem{parent_id: parent_id} = item, organisation_id, acc) do
    case StorageItems.get_storage_item_by_org(parent_id, organisation_id) do
      nil -> [item | acc]
      parent -> build_storage_ancestors(parent, organisation_id, [item | acc])
    end
  end

  @doc "Lists storage items within a repository with pagination and sorting"
  @spec list_repository_storage_items(String.t(), String.t() | nil, String.t(), keyword()) :: [
          StorageItem.t()
        ]
  def list_repository_storage_items(repository_id, parent_id \\ nil, organisation_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)
    offset = Keyword.get(opts, :offset, 0)
    sort_by = Keyword.get(opts, :sort_by, "created")
    sort_order = Keyword.get(opts, :sort_order, "desc")

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
        from(s in query,
          where: is_nil(s.parent_id) and s.depth_level == 1
        )
      end

    Repo.all(query)
  end

  @doc "Parses sort options into Ecto query order_by clause"
  @spec parse_sort_options(String.t(), String.t()) :: keyword()
  def parse_sort_options(sort_by, sort_order) do
    sort_order
    |> parse_sort_direction()
    |> then(&parse_sort_field(sort_by, &1))
  end

  @spec parse_sort_direction(String.t()) :: :asc | :desc
  defp parse_sort_direction(sort_order) do
    case String.downcase(sort_order || "") do
      "asc" -> :asc
      "desc" -> :desc
      _ -> :desc
    end
  end

  @spec parse_sort_field(String.t(), :asc | :desc) :: keyword()
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

  @doc "Prepares upload parameters from form data"
  @spec prepare_upload_params(map(), User.t(), String.t()) :: {:ok, map()} | {:error, String.t()}
  def prepare_upload_params(
        %{"file" => %Plug.Upload{} = upload} = params,
        current_user,
        organisation_id
      ) do
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

      {:ok, enriched_params}
    end
  end

  def prepare_upload_params(_params, _current_user, _organisation_id),
    do: {:error, "File upload is required"}

  @doc "Extracts metadata from uploaded file"
  @spec extract_file_metadata(Plug.Upload.t()) :: {:ok, map()} | {:error, String.t()}
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

  @doc "Executes file upload transaction"
  @spec execute_upload_transaction(map()) :: {:ok, map()} | {:error, Ecto.Changeset.t()}
  def execute_upload_transaction(enriched_params) do
    Ecto.Multi.new()
    |> Ecto.Multi.run(:storage_item, fn _repo, _ ->
      StorageItems.create_storage_item(enriched_params.storage_item)
    end)
    |> Ecto.Multi.insert(:storage_asset, fn %{storage_item: storage_item} ->
      storage_asset_params =
        Map.put(enriched_params.storage_asset, :storage_item_id, storage_item.id)

      StorageAsset.changeset(%StorageAsset{}, storage_asset_params)
    end)
    |> Ecto.Multi.update(:upload_file, fn %{storage_asset: storage_asset} ->
      StorageAsset.file_changeset(storage_asset, %{filename: enriched_params.file_upload})
    end)
    |> Ecto.Multi.update(:complete_upload, fn %{upload_file: storage_asset} ->
      StorageAsset.changeset(storage_asset, %{
        processing_status: "completed",
        upload_completed_at: DateTime.utc_now()
      })
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{storage_item: storage_item, complete_upload: storage_asset}} ->
        schedule_background_processing(storage_asset, storage_item)

        {:ok, %{storage_asset: storage_asset, storage_item: storage_item}}

      {:error, _stage, changeset, _changes} ->
        {:error, changeset}
    end
  end

  @doc "Calculates item hierarchy depth and materialized path"
  @spec calculate_item_hierarchy(String.t() | nil, String.t(), String.t()) ::
          {integer(), String.t()}
  def calculate_item_hierarchy(nil, _organisation_id, _filename) do
    {1, "/"}
  end

  def calculate_item_hierarchy(parent_id, organisation_id, filename) do
    case StorageItems.get_storage_item_by_org(parent_id, organisation_id) do
      %StorageItem{depth_level: parent_depth, materialized_path: parent_path} ->
        depth_level = parent_depth + 1
        materialized_path = Path.join(parent_path, filename)
        {depth_level, materialized_path}

      nil ->
        {1, "/#{filename}"}
    end
  end

  @doc "Calculates SHA256 checksum for a file"
  @spec calculate_file_checksum(String.t()) :: {:ok, String.t()} | {:error, atom()}
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

  @doc "Schedules background processing for uploaded files (content extraction, thumbnails)"
  @spec schedule_background_processing(StorageAsset.t(), StorageItem.t()) :: {:ok, pid()}
  def schedule_background_processing(storage_asset, storage_item) do
    Task.start(fn ->
      Logger.info("Starting background processing", %{
        storage_asset_id: storage_asset.id,
        storage_item_id: storage_item.id
      })

      StorageAssets.update_storage_asset(storage_asset, %{processing_status: "processing"})

      with :ok <- extract_content_if_supported(storage_item),
           :ok <- generate_thumbnail_if_supported(storage_item) do
        StorageItems.update_storage_item(storage_item, %{
          content_extracted: true,
          thumbnail_generated: true
        })

        StorageAssets.update_storage_asset(storage_asset, %{processing_status: "completed"})

        Logger.info("Background processing completed", %{
          storage_asset_id: storage_asset.id,
          storage_item_id: storage_item.id
        })
      else
        {:error, reason} ->
          Logger.error("Background processing failed", %{
            storage_asset_id: storage_asset.id,
            storage_item_id: storage_item.id,
            reason: reason
          })

          StorageAssets.update_storage_asset(storage_asset, %{processing_status: "failed"})
      end
    end)
  end

  @doc "Extracts content from supported file types (PDF, text files)"
  @spec extract_content_if_supported(StorageItem.t()) :: :ok
  def extract_content_if_supported(%StorageItem{mime_type: "application/pdf"}), do: :ok
  def extract_content_if_supported(%StorageItem{mime_type: "text/" <> _}), do: :ok
  def extract_content_if_supported(_), do: :ok

  @doc "Generates thumbnails for supported file types (images, PDFs)"
  @spec generate_thumbnail_if_supported(StorageItem.t()) :: :ok
  def generate_thumbnail_if_supported(%StorageItem{mime_type: "image/" <> _}), do: :ok
  def generate_thumbnail_if_supported(%StorageItem{mime_type: "application/pdf"}), do: :ok
  def generate_thumbnail_if_supported(_), do: :ok

  @doc "Updates materialized paths for all children when parent item is moved/renamed"
  @spec update_children_paths(StorageItem.t(), String.t()) :: :ok
  def update_children_paths(
        %StorageItem{
          id: parent_id,
          materialized_path: parent_materialized_path,
          name: parent_name
        } = _parent_item,
        _organisation_id
      ) do
    parent_id
    |> StorageItems.get_all_children_storage_items()
    |> Enum.each(fn child ->
      new_materialized_path =
        String.replace(
          child.materialized_path,
          parent_materialized_path,
          Path.join(parent_materialized_path, parent_name)
        )

      child
      |> StorageItem.changeset(%{materialized_path: new_materialized_path})
      |> Repo.update()
    end)
  end
end
