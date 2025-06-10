defmodule WraftDocWeb.Api.V1.StorageAssetsController do
  use WraftDocWeb, :controller
  require Logger

  alias WraftDoc.Storage
  alias WraftDoc.Storage.StorageItem

  action_fallback WraftDocWeb.FallbackController

    @doc """
  Lists storage items in the root folder or a specific folder.

  Query parameters:
  - folder_id: Optional folder ID to list contents of a specific folder
  - repository_id: Optional repository ID to filter by repository
  - parent_id: Optional parent ID when using repository_id
  - limit: Number of items to return (1-1000, default: 100)
  - offset: Number of items to skip (default: 0)

  If no folder_id is provided, returns root level items.
  If folder_id is provided, returns children of that folder.
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
    # Parse pagination parameters
    limit = parse_integer(params["limit"], 100, 1, 1000)
    offset = parse_integer(params["offset"], 0, 0, nil)
    pagination_opts = [limit: limit, offset: offset]

    storage_items = case params do
      %{"folder_id" => folder_id} when folder_id != "" ->
        # Validate that the folder exists and belongs to the organization
        case Storage.get_storage_item_by_org(folder_id, organisation_id) do
          %StorageItem{mime_type: "inode/directory"} = _folder ->
            Storage.list_storage_items_by_parent(folder_id, organisation_id, pagination_opts)
          %StorageItem{} ->
            {:error, :not_a_directory}
          nil ->
            {:error, :folder_not_found}
        end

      %{"repository_id" => repository_id} when repository_id != "" ->
        parent_id = Map.get(params, "parent_id")
        Storage.list_repository_storage_items(repository_id, parent_id, organisation_id, pagination_opts)

      _ ->
        Storage.list_root_storage_items(organisation_id, pagination_opts)
    end

    case storage_items do
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

      items ->
        Logger.info("Storage assets listed", %{
          organisation_id: organisation_id,
          count: length(items),
          params: Map.take(params, ["folder_id", "repository_id", "parent_id", "limit", "offset"])
        })
        render(conn, :index, storage_items: items)
    end
  end

    @doc """
  Shows details of a specific storage item.
  """
  def show(conn, %{"id" => id}) do
    current_user = conn.assigns[:current_user]
    organisation_id = current_user.current_org_id

    try do
      storage_item = Storage.get_storage_item_by_org!(id, organisation_id)
      render(conn, :show, storage_item: storage_item)
    rescue
      Ecto.NoResultsError ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Storage item not found"})
    end
  end

  @doc """
  Gets breadcrumb navigation for a storage item.
  """
  def breadcrumbs(conn, %{"id" => id}) do
    current_user = conn.assigns[:current_user]
    organisation_id = current_user.current_org_id

    with :ok <- validate_uuid_param(%{"id" => id}, "id") do
      breadcrumbs = Storage.get_storage_item_breadcrumbs(id, organisation_id)

      conn
      |> json(%{
        data: for(item <- breadcrumbs, do: breadcrumb_data(item))
      })
    else
      {:error, _field} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid UUID format for id"})
    end
  end

  @doc """
  Gets statistics for a folder or root directory.
  """
  def stats(conn, params) do
    current_user = conn.assigns[:current_user]
    organisation_id = current_user.current_org_id

    parent_id = Map.get(params, "parent_id")

    with :ok <- validate_uuid_param(params, "parent_id") do
      stats = Storage.get_storage_item_stats(parent_id, organisation_id)

      conn
      |> json(%{
        data: stats
      })
    else
      {:error, _field} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid UUID format for parent_id"})
    end
  end

  @doc """
  Searches storage items by name.
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

      item_type_filter = case Map.get(params, "type") do
        "folders" -> :folders
        "files" -> :files
        _ -> nil
      end

      search_opts = [
        limit: limit,
        offset: offset,
        item_type: item_type_filter
      ]

      results = Storage.search_storage_items(search_term, organisation_id, search_opts)

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
      nil -> :ok
      "" -> :ok
      value when is_binary(value) ->
        case Ecto.UUID.cast(value) do
          {:ok, _} -> :ok
          :error -> {:error, key}
        end
      _ -> {:error, key}
    end
  end
end
