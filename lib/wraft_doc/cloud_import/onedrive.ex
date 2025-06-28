defmodule WraftDoc.CloudImport.Onedrive do
  @moduledoc """
  Unified cloud service client for Google Drive, Dropbox, and OneDrive APIs.
  """

  use Tesla
  require Logger
  alias WraftDoc.Storage.StorageItems
  alias WraftDoc.Workers.CloudImportWorker, as: Worker

  # Configuration for different cloud services
  # @google_drive_base "https://www.googleapis.com/drive/v3"
  # @dropbox_base "https://api.dropboxapi.com/2"
  # @dropbox_content_base "https://content.dropboxapi.com/2"
  @onedrive_base "https://graph.microsoft.com/v1.0"

  # Default Tesla middleware stack
  plug Tesla.Middleware.Headers, [
    {"user-agent", "wraftdoc"}
  ]

  plug Tesla.Middleware.JSON
  plug Tesla.Middleware.FollowRedirects
  plug Tesla.Middleware.Logger

  adapter(Tesla.Adapter.Hackney,
    timeout: 15_000,
    recv_timeout: 15_000
  )

  def list_all_files(access_token, params) do
    opts = Map.to_list(params)
    path = Keyword.get(opts, :path, "/drive/root/children")
    query = Keyword.get(opts, :query, "")

    url = "#{@onedrive_base}/me#{path}"
    query_params = if query != "", do: [filter: query], else: []

    handle_response(
      get(url,
        query: query_params,
        headers: auth_headers(access_token)
      )
    )
  end

  def list_all_files_recursive(access_token, params, acc \\ []) do
    case list_all_files(access_token, params) do
      {:ok, %{"files" => files, "nextPageToken" => next_token}} ->
        new_params = Map.put(params, "page_token", next_token)
        list_all_files_recursive(access_token, new_params, acc ++ files)

      {:ok, %{"files" => files}} ->
        {:ok, acc ++ files}

      error ->
        error
    end
  end

  def get_file_metadata(access_token, item_id) do
    handle_response(
      get("#{@onedrive_base}/me/drive/items/#{item_id}",
        headers: auth_headers(access_token)
      )
    )
  end

  def list_all_pdfs(access_token, params) do
    opts = Map.to_list(params)
    top = Keyword.get(opts, :top, 1000)

    get =
      get("#{@onedrive_base}/me/drive/root/children",
        query: [
          "$top": top,
          "$select": "id,name,size,lastModifiedDateTime,webUrl,file",
          "$filter": "file ne null"
        ],
        headers: auth_headers(access_token)
      )

    case handle_response(get) do
      {:ok, %{"value" => entries}} ->
        pdfs =
          Enum.filter(entries, fn file ->
            name = String.downcase(file["name"] || "")
            String.ends_with?(name, ".pdf") && Map.has_key?(file, "file")
          end)

        {:ok, %{"files" => pdfs}}

      error ->
        error
    end
  end

  def list_all_folders(access_token, params) do
    opts = Map.to_list(params)
    path = Keyword.get(opts, :path, "/drive/root/children")

    get =
      get("#{@onedrive_base}/me#{path}",
        query: [
          "$select": "id,name,createdDateTime,lastModifiedDateTime,folder",
          "$filter": "folder ne null"
        ],
        headers: auth_headers(access_token)
      )

    case handle_response(get) do
      {:ok, %{"value" => entries}} ->
        folders = Enum.filter(entries, &Map.has_key?(&1, "folder"))
        {:ok, %{"folders" => folders}}

      error ->
        error
    end
  end

  def sync_files_to_db(access_token, params) do
    with {:ok, %{"files" => files}} <- list_all_files(access_token, params) do
      results =
        files
        |> Enum.map(&Task.async(fn -> save_files_to_db(&1) end))
        |> Enum.map(&Task.await(&1, 15_000))

      stats = calculate_sync_stats(results, files)

      {:ok, stats}
    end
  end

  def schedule_download_to_minio(access_token, file_id, org_id, metadata \\ %{}) do
    action = String.replace("download_onedrive_to_minio", "_drive", "")

    params = %{
      action: action,
      file_id: file_id,
      access_token: access_token,
      org_id: org_id,
      user_id: metadata["user_id"],
      notification_enabled: Map.get(metadata, "notification_enabled", true)
    }

    params
    |> Worker.new()
    |> Oban.insert()
  end

  def search_files(access_token, opts) do
    # Convert opts to map if it's a keyword list
    opts = if Keyword.keyword?(opts), do: Map.new(opts), else: opts

    query = Map.get(opts, "query", "") || Map.get(opts, :query, "")
    content_type = Map.get(opts, "content_type") || Map.get(opts, :content_type)
    limit = Map.get(opts, "limit", 100) || Map.get(opts, :limit, 100)

    search_onedrive(access_token, query, content_type, limit)
  end

  def search_folders(access_token, opts) do
    query = Keyword.get(opts, :query, "")
    top = Keyword.get(opts, :top, 100)

    search_query =
      if query == "" do
        ""
      else
        "search(q='#{query}')"
      end

    endpoint =
      if query == "" do
        "#{@onedrive_base}/me/drive/root/children"
      else
        "#{@onedrive_base}/me/drive/#{search_query}"
      end

    get =
      get(endpoint,
        query: [
          "$top": top,
          "$select": "id,name,createdDateTime,lastModifiedDateTime,folder",
          "$filter": "folder ne null"
        ],
        headers: auth_headers(access_token)
      )

    case handle_response(get) do
      {:ok, %{"value" => entries}} ->
        folders = Enum.filter(entries, &Map.has_key?(&1, "folder"))
        {:ok, %{"folders" => folders}}

      error ->
        error
    end
  end

  def list_files_in_folder(access_token, folder_id, params) do
    opts = Map.to_list(params)
    top = Keyword.get(opts, :top, 1000)
    file_type = Keyword.get(opts, :file_type, "all")

    filter_query =
      case file_type do
        "pdf" ->
          "file ne null and endswith(name,'.pdf')"

        "image" ->
          "file ne null and (endswith(name,'.jpg') or endswith(name,'.jpeg') or endswith(name,'.png') or endswith(name,'.gif') or endswith(name,'.bmp'))"

        "document" ->
          "file ne null and (endswith(name,'.doc') or endswith(name,'.docx') or endswith(name,'.txt'))"

        _ ->
          "file ne null"
      end

    get =
      get("#{@onedrive_base}/me/drive/items/#{folder_id}/children",
        query: [
          "$top": top,
          "$select": "id,name,size,lastModifiedDateTime,webUrl,file,createdDateTime",
          "$filter": filter_query
        ],
        headers: auth_headers(access_token)
      )

    case handle_response(get) do
      {:ok, %{"value" => entries}} ->
        files = Enum.filter(entries, &Map.has_key?(&1, "file"))
        {:ok, %{"files" => files}}

      error ->
        error
    end
  end

  def get_folder_metadata(access_token, folder_id) do
    handle_response(
      get("#{@onedrive_base}/me/drive/items/#{folder_id}",
        query: ["$select": "id,name,createdDateTime,lastModifiedDateTime,folder,parentReference"],
        headers: auth_headers(access_token)
      )
    )
  end

  defp search_onedrive(access_token, query, content_type, limit) do
    base_url = "#{@onedrive_base}/me/drive/root/search"

    query_params = [
      {"$top", to_string(limit)},
      {"$select", "id,name,size,lastModifiedDateTime,file"},
      {"q", query}
    ]

    query_params =
      if content_type do
        [{"$filter", "file/mimeType eq '#{content_type}'"} | query_params]
      else
        query_params
      end

    get =
      get(base_url,
        query: query_params,
        headers: auth_headers(access_token)
      )

    case handle_response(get) do
      {:ok, %{"value" => files}} -> {:ok, %{"files" => files}}
      error -> error
    end
  end

  @spec parse_size(any()) :: integer()
  defp parse_size(nil), do: 0
  defp parse_size(size) when is_binary(size), do: String.to_integer(size)
  defp parse_size(size) when is_integer(size), do: size
  defp parse_size(_), do: 0

  defp calculate_sync_stats(results, files) do
    success_count = Enum.count(results, &(&1 == :ok))

    %{
      total: length(files),
      success: success_count,
      errors: length(files) - success_count,
      results: results
    }
  end

  defp auth_headers(access_token) do
    [{"Authorization", "Bearer #{access_token}"}]
  end

  defp handle_response({:ok, %{status: status, body: body}}) when status in 200..299 do
    {:ok, body}
  end

  defp handle_response({:ok, %{status: status, body: body}}) do
    {:error, %{status: status, body: body}}
  end

  defp handle_response({:error, reason}) do
    {:error, %{status: 500, body: reason}}
  end

  defp save_files_to_db(file) do
    attrs = %{
      sync_source: "onedrive",
      external_id: file["id"],
      name: file["name"],
      path: file["pathDisplay"] || "",
      materalized_path: file["pathDisplay"] || "",
      mime_type: file["mimeType"],
      metadata: %{description: file["description"] || ""},
      size: parse_size(file["size"]),
      modified_time: file["modifiedTime"],
      external_metadata: %{
        owner: file["owners"],
        created_time: file["createdTime"],
        parents: file["parents"]
      },
      file_extension: file["fileExtension"]
    }

    case StorageItems.create_storage_item(attrs) do
      {:ok, _} -> :ok
      error -> error
    end
  end
end
