defmodule WraftDoc.CloudImport.Clouds do
  @moduledoc """
  Unified cloud service client for Google Drive, Dropbox, and OneDrive APIs.
  """

  use Tesla
  require Logger
  alias WraftDoc.Storage.StorageItems
  alias WraftDoc.Workers.CloudImportWorker, as: Worker

  # Configuration for different cloud services
  # @google_drive_base "https://www.googleapis.com/drive/v3"
  @dropbox_base "https://api.dropboxapi.com/2"
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

  # ============================================================================
  # File Listing
  # ============================================================================

  @doc """
  List all files from the specified cloud service.

  ## Parameters
  - `service`: Atom representing the cloud service (:google_drive, :dropbox, :onedrive)
  - `access_token`: OAuth2 access token
  - `params`: Keyword list of options:
    - For Google Drive:
      - `:page_size`: Number of items per page (default: 100)
      - `:query`: Search query string
    - For Dropbox:
      - `:path`: Path to list (default: "")
      - `:recursive`: Boolean for recursive listing (default: false)
    - For OneDrive:
      - `:path`: Path to list (default: "/drive/root/children")
      - `:query`: Search query string

  ## Examples
      iex> list_all_files(:google_drive, "token123", page_size: 50, query: "name contains 'report'")
      {:ok, %{"files" => [...]}}
  """
  @spec list_all_files(atom(), String.t(), keyword()) ::
          {:ok, map()} | {:error, map()}

  def list_all_files(:dropbox, access_token, params) do
    opts = Map.to_list(params)
    path = Keyword.get(opts, :path, "")
    recursive = Keyword.get(opts, :recursive, false)

    body = %{
      path: path,
      recursive: recursive,
      include_media_info: true,
      include_deleted: false
    }

    post =
      post("#{@dropbox_base}/files/list_folder", body,
        headers: auth_headers(:dropbox, access_token)
      )

    case handle_response(post) do
      {:ok, %{"entries" => entries}} ->
        files = Enum.filter(entries, &(&1[".tag"] == "file"))
        {:ok, %{"files" => files}}

      error ->
        error
    end
  end

  def list_all_files(:onedrive, access_token, params) do
    opts = Map.to_list(params)
    path = Keyword.get(opts, :path, "/drive/root/children")
    query = Keyword.get(opts, :query, "")

    url = "#{@onedrive_base}/me#{path}"
    query_params = if query != "", do: [filter: query], else: []

    handle_response(
      get(url,
        query: query_params,
        headers: auth_headers(:onedrive, access_token)
      )
    )
  end

  def list_all_files_recursive(service, access_token, params, acc \\ []) do
    case list_all_files(service, access_token, params) do
      {:ok, %{"files" => files, "nextPageToken" => next_token}} ->
        new_params = Map.put(params, "page_token", next_token)
        list_all_files_recursive(service, access_token, new_params, acc ++ files)

      {:ok, %{"files" => files}} ->
        {:ok, acc ++ files}

      error ->
        error
    end
  end

  # ============================================================================
  # File Metadata
  # ============================================================================

  @doc """
  Get file metadata from the specified cloud service.

  ## Parameters
  - `service`: Atom representing the cloud service
  - `access_token`: OAuth2 access token
  - `file_id`: ID or path of the file

  ## Examples
      iex> get_file_metadata(:google_drive, "token123", "file123")
      {:ok, %{"name" => "report.pdf", "size" => "1024", ...}}
  """
  @spec get_file_metadata(atom(), String.t(), String.t()) ::
          {:ok, map()} | {:error, map()}

  def get_file_metadata(:onedrive, access_token, item_id) do
    handle_response(
      get("#{@onedrive_base}/me/drive/items/#{item_id}",
        headers: auth_headers(:onedrive, access_token)
      )
    )
  end

  def get_file_metadata(:dropbox, access_token, file_path) do
    body = %{path: file_path}

    handle_response(
      post("#{@dropbox_base}/files/get_metadata", body,
        headers: auth_headers(:dropbox, access_token)
      )
    )
  end

  # ============================================================================
  # PDF Operations
  # ============================================================================

  @doc """
  List all PDF files from the specified cloud service.

  ## Parameters
  - `service`: Atom representing the cloud service
  - `access_token`: OAuth2 access token
  - `params`: Service-specific parameters (same as list_all_files)

  ## Examples
      iex> list_all_pdfs(:google_drive, "token123", page_size: 200)
      {:ok, %{"files" => [%{"name" => "doc.pdf", ...}, ...]}}
  """
  @spec list_all_pdfs(atom(), String.t(), keyword()) ::
          {:ok, map()} | {:error, map()}
  def list_all_pdfs(service, access_token, params \\ [])

  def list_all_pdfs(:dropbox, access_token, params) do
    opts = Map.to_list(params)
    path = Keyword.get(opts, :path, "")
    limit = Keyword.get(opts, :limit, 2000)
    recursive = Keyword.get(opts, :recursive, false)

    body = %{
      path: path,
      limit: limit,
      recursive: recursive,
      include_media_info: false,
      include_deleted: false
    }

    post =
      post("#{@dropbox_base}/files/list_folder", body,
        headers: auth_headers(:dropbox, access_token)
      )

    case handle_response(post) do
      {:ok, %{"entries" => entries}} ->
        pdfs =
          Enum.filter(entries, fn entry ->
            entry[".tag"] == "file" &&
              String.ends_with?(String.downcase(entry["name"] || ""), ".pdf")
          end)

        {:ok, %{"files" => pdfs}}

      error ->
        error
    end
  end

  def list_all_pdfs(:onedrive, access_token, params) do
    opts = Map.to_list(params)
    top = Keyword.get(opts, :top, 1000)

    get =
      get("#{@onedrive_base}/me/drive/root/children",
        query: [
          "$top": top,
          "$select": "id,name,size,lastModifiedDateTime,webUrl,file",
          "$filter": "file ne null"
        ],
        headers: auth_headers(:onedrive, access_token)
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

  # ============================================================================
  # Sync Operations
  # ============================================================================

  @doc """
  Sync files metadata to database.

  ## Parameters
  - `service`: Atom representing the cloud service
  - `access_token`: OAuth2 access token
  - `opts`: Keyword list of options (same as list_all_files)

  ## Examples
      iex> sync_files_to_db(:google_drive, "token123", page_size: 500)
      {:ok, %{total: 150, success: 148, errors: 2}}
  """

  def sync_files_to_db(service, access_token, params) do
    with {:ok, %{"files" => files}} <- list_all_files(service, access_token, params) do
      results =
        files
        |> Enum.map(&Task.async(fn -> save_files_to_db(service, &1) end))
        |> Enum.map(&Task.await(&1, 15_000))

      stats = calculate_sync_stats(results, files)

      {:ok, stats}
    end
  end

  # ============================================================================
  # Search Operations
  # ============================================================================

  @doc """
  Search for files across cloud services.

  ## Options
  - `query`: Search string
  - `content_type`: Filter by mime type (e.g., "application/pdf")
  - `limit`: Maximum results to return (default: 100)

  ## Examples
      iex> search_files(:google_drive, "token123", query: "annual report", content_type: "application/pdf")
      {:ok, %{"files" => [...]}}
  """
  @spec search_files(atom(), String.t(), map() | keyword()) ::
          {:ok, list(map())} | {:error, map()}
  def search_files(service, access_token, opts) do
    # Convert opts to map if it's a keyword list
    opts = if Keyword.keyword?(opts), do: Map.new(opts), else: opts

    query = Map.get(opts, "query", "") || Map.get(opts, :query, "")
    content_type = Map.get(opts, "content_type") || Map.get(opts, :content_type)
    limit = Map.get(opts, "limit", 100) || Map.get(opts, :limit, 100)

    case service do
      #   :google_drive ->
      #  #   search_google_drive(access_token, query, content_type, limit)

      :dropbox ->
        search_dropbox(access_token, query, content_type, limit)

      :onedrive ->
        search_onedrive(access_token, query, content_type, limit)

      _ ->
        {:error, %{message: "Unsupported service", service: service}}
    end
  end

  # ============================================================================
  # Download Operations
  # ============================================================================

  # @doc """
  # Download a file from the specified cloud service.

  # ## Parameters
  # - `service`: Atom representing the cloud service
  # - `access_token`: OAuth2 access token
  # - `file_id`: ID or path of the file
  # - `output_path`: Optional path to save the file (if nil, returns binary content)

  # ## Examples
  #     iex> download_file(:google_drive, "token123", "file123", "/tmp/report.pdf")
  #     {:ok, %{path: "/tmp/report.pdf", metadata: %{...}}}
  # """

  @doc """
  Schedule file download to MinIO.

  ## Parameters
  - `service`: Atom representing the cloud service
  - `access_token`: OAuth2 access token
  - `file_id`: ID or path of the file
  - `org_id`: Organization ID
  - `metadata`: Additional metadata to include

  ## Examples
      iex> schedule_download_to_minio(:google_drive, "token123", "file123", "org123", %{user_id: "user123"})
      {:ok, %Oban.Job{}}
  """
  @spec schedule_download_to_minio(atom(), String.t(), String.t(), String.t(), map()) ::
          {:ok, Oban.Job.t()} | {:error, Ecto.Changeset.t()}
  def schedule_download_to_minio(service, access_token, file_id, org_id, metadata \\ %{}) do
    action = String.replace("download_#{service}_to_minio", "_drive", "")

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

  # =============================================================================
  # Folder Operations
  # =============================================================================

  @doc """
  List all folders from the specified cloud service.

  ## Parameters
  - `service`: Atom representing the cloud service (:google_drive, :dropbox, :onedrive)
  - `access_token`: OAuth2 access token
  - `params`: Keyword list of options:
    - For Google Drive:
      - `:page_size`: Number of items per page (default: 100)
      - `:parent_id`: Parent folder ID to list folders from (default: "root")
    - For Dropbox:
      - `:path`: Path to list folders from (default: "")
      - `:recursive`: Boolean for recursive listing (default: false)
    - For OneDrive:
      - `:path`: Path to list folders from (default: "/drive/root/children")

  ## Examples
      iex> list_all_folders(:google_drive, "token123", page_size: 50, parent_id: "folder123")
      {:ok, %{"files" => [%{"name" => "Documents", "id" => "folder456", ...}, ...]}}

      iex> list_all_folders(:dropbox, "token123", path: "/work", recursive: true)
      {:ok, %{"folders" => [%{"name" => "projects", "path_display" => "/work/projects", ...}, ...]}}

      iex> list_all_folders(:onedrive, "token123", path: "/drive/items/folder123/children")
      {:ok, %{"folders" => [%{"name" => "Reports", "id" => "folder789", ...}, ...]}}

  ## Returns
  - `{:ok, map()}`: Success with folders data
  - `{:error, map()}`: Error with status and body information
  """
  @spec list_all_folders(atom(), String.t(), keyword()) ::
          {:ok, map()} | {:error, map()}

  def list_all_folders(:dropbox, access_token, params) do
    opts = Map.to_list(params)
    path = Keyword.get(opts, :path, "")
    recursive = Keyword.get(opts, :recursive, false)

    body = %{
      path: path,
      recursive: recursive,
      include_media_info: false,
      include_deleted: false
    }

    post =
      post("#{@dropbox_base}/files/list_folder", body,
        headers: auth_headers(:dropbox, access_token)
      )

    case handle_response(post) do
      {:ok, %{"entries" => entries}} ->
        folders = Enum.filter(entries, &(&1[".tag"] == "folder"))
        {:ok, %{"folders" => folders}}

      error ->
        error
    end
  end

  def list_all_folders(:onedrive, access_token, params) do
    opts = Map.to_list(params)
    path = Keyword.get(opts, :path, "/drive/root/children")

    get =
      get("#{@onedrive_base}/me#{path}",
        query: [
          "$select": "id,name,createdDateTime,lastModifiedDateTime,folder",
          "$filter": "folder ne null"
        ],
        headers: auth_headers(:onedrive, access_token)
      )

    case handle_response(get) do
      {:ok, %{"value" => entries}} ->
        folders = Enum.filter(entries, &Map.has_key?(&1, "folder"))
        {:ok, %{"folders" => folders}}

      error ->
        error
    end
  end

  @doc """
  Search for folders across cloud services.

  ## Parameters
  - `service`: Atom representing the cloud service (:google_drive, :dropbox, :onedrive)
  - `access_token`: OAuth2 access token
  - `opts`: Keyword list of options:
    - `:query`: Search query string (default: "")
    - For Google Drive:
      - `:page_size`: Number of items per page (default: 100)
    - For Dropbox:
      - `:max_results`: Maximum results to return (default: 100)
    - For OneDrive:
      - `:top`: Maximum results to return (default: 100)

  ## Examples
      iex> search_folders(:google_drive, "token123", query: "project", page_size: 50)
      {:ok, %{"files" => [%{"name" => "Project Alpha", ...}, ...]}}

      iex> search_folders(:dropbox, "token123", query: "documents", max_results: 25)
      {:ok, %{"folders" => [%{"name" => "My Documents", ...}, ...]}}

      iex> search_folders(:onedrive, "token123", query: "reports", top: 20)
      {:ok, %{"folders" => [%{"name" => "Annual Reports", ...}, ...]}}

  ## Returns
  - `{:ok, map()}`: Success with matching folders
  - `{:error, map()}`: Error with status and body information
  """
  @spec search_folders(atom(), String.t(), keyword()) ::
          {:ok, list(map())} | {:error, map()}

  def search_folders(:dropbox, access_token, opts) do
    opts = if Keyword.keyword?(opts), do: Map.new(opts), else: opts

    query = Map.get(opts, "query", "") || Map.get(opts, :query, "")
    max_results = Map.get(opts, "max_results", 100) || Map.get(opts, :max_results, 100)

    body = %{
      query: query,
      options: %{
        path: "",
        max_results: max_results,
        file_status: "active",
        filename_only: true
      },
      match_field_options: %{
        include_highlights: false
      }
    }

    post =
      post("#{@dropbox_base}/files/search_v2", body,
        headers: auth_headers(:dropbox, access_token)
      )

    case handle_response(post) do
      {:ok, %{"matches" => matches}} ->
        folders =
          matches
          |> Enum.filter(fn match ->
            get_in(match, ["metadata", "metadata", ".tag"]) == "folder"
          end)
          |> Enum.map(fn match ->
            get_in(match, ["metadata", "metadata"])
          end)

        {:ok, %{"folders" => folders}}

      error ->
        error
    end
  end

  def search_folders(:onedrive, access_token, opts) do
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
        headers: auth_headers(:onedrive, access_token)
      )

    case handle_response(get) do
      {:ok, %{"value" => entries}} ->
        folders = Enum.filter(entries, &Map.has_key?(&1, "folder"))
        {:ok, %{"folders" => folders}}

      error ->
        error
    end
  end

  @doc """
  List files within a specific folder from the specified cloud service.

  ## Parameters
  - `service`: Atom representing the cloud service (:google_drive, :dropbox, :onedrive)
  - `access_token`: OAuth2 access token
  - `folder_id_or_path`: Folder ID (Google Drive, OneDrive) or path (Dropbox)
  - `params`: Keyword list of options:
    - `:file_type`: Filter by file type ("all", "pdf", "image", "document") (default: "all")
    - For Google Drive:
      - `:page_size`: Number of items per page (default: 100)
    - For Dropbox:
      - `:recursive`: Boolean for recursive listing (default: false)
      - `:limit`: Maximum results to return (default: 2000)
    - For OneDrive:
      - `:top`: Maximum results to return (default: 1000)

  ## Examples
      iex> list_files_in_folder(:google_drive, "token123", "folder123", file_type: "pdf", page_size: 50)
      {:ok, %{"files" => [%{"name" => "report.pdf", "mimeType" => "application/pdf", ...}, ...]}}

      iex> list_files_in_folder(:dropbox, "token123", "/documents", recursive: true, file_type: "image")
      {:ok, %{"files" => [%{"name" => "photo.jpg", ...}, ...]}}

      iex> list_files_in_folder(:onedrive, "token123", "folder456", file_type: "document", top: 100)
      {:ok, %{"files" => [%{"name" => "document.docx", ...}, ...]}}

  ## Returns
  - `{:ok, map()}`: Success with files data
  - `{:error, map()}`: Error with status and body information
  """
  @spec list_files_in_folder(atom(), String.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, map()}

  def list_files_in_folder(:dropbox, access_token, folder_path, params) do
    opts = Map.to_list(params)
    recursive = Keyword.get(opts, :recursive, false)
    file_type = Keyword.get(opts, :file_type, "all")
    limit = Keyword.get(opts, :limit, 2000)

    body = %{
      path: folder_path,
      recursive: recursive,
      include_media_info: true,
      include_deleted: false,
      limit: limit
    }

    post =
      post("#{@dropbox_base}/files/list_folder", body,
        headers: auth_headers(:dropbox, access_token)
      )

    case handle_response(post) do
      {:ok, %{"entries" => entries}} ->
        files =
          entries
          |> Enum.filter(&(&1[".tag"] == "file"))
          |> filter_files_by_type(file_type)

        {:ok, %{"files" => files}}

      error ->
        error
    end
  end

  def list_files_in_folder(:onedrive, access_token, folder_id, params) do
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
        headers: auth_headers(:onedrive, access_token)
      )

    case handle_response(get) do
      {:ok, %{"value" => entries}} ->
        files = Enum.filter(entries, &Map.has_key?(&1, "file"))
        {:ok, %{"files" => files}}

      error ->
        error
    end
  end

  @doc """
  Get folder metadata from the specified cloud service.

  ## Parameters
  - `service`: Atom representing the cloud service (:google_drive, :dropbox, :onedrive)
  - `access_token`: OAuth2 access token
  - `folder_id_or_path`: Folder ID (Google Drive, OneDrive) or path (Dropbox)

  ## Examples
      iex> get_folder_metadata(:google_drive, "token123", "folder123")
      {:ok, %{"id" => "folder123", "name" => "Documents", "mimeType" => "application/vnd.google-apps.folder", ...}}

      iex> get_folder_metadata(:dropbox, "token123", "/work/projects")
      {:ok, %{"name" => "projects", "path_display" => "/work/projects", ".tag" => "folder", ...}}

      iex> get_folder_metadata(:onedrive, "token123", "folder456")
      {:ok, %{"id" => "folder456", "name" => "Reports", "folder" => %{}, ...}}

  ## Returns
  - `{:ok, map()}`: Success with folder metadata
  - `{:error, map()}`: Error with status and body information
  """
  @spec get_folder_metadata(atom(), String.t(), String.t()) ::
          {:ok, map()} | {:error, map()}
  def get_folder_metadata(:dropbox, access_token, folder_path) do
    body = %{path: folder_path}

    handle_response(
      post("#{@dropbox_base}/files/get_metadata", body,
        headers: auth_headers(:dropbox, access_token)
      )
    )
  end

  def get_folder_metadata(:onedrive, access_token, folder_id) do
    handle_response(
      get("#{@onedrive_base}/me/drive/items/#{folder_id}",
        query: ["$select": "id,name,createdDateTime,lastModifiedDateTime,folder,parentReference"],
        headers: auth_headers(:onedrive, access_token)
      )
    )
  end

  @spec filter_files_by_type(list(map()), String.t()) :: list(map())
  defp filter_files_by_type(files, "all"), do: files

  defp filter_files_by_type(files, file_type) do
    Enum.filter(files, fn file ->
      name = String.downcase(file["name"] || "")

      case file_type do
        "pdf" -> String.ends_with?(name, ".pdf")
        "image" -> String.ends_with?(name, [".jpg", ".jpeg", ".png", ".gif", ".bmp"])
        "document" -> String.ends_with?(name, [".doc", ".docx", ".txt", ".rtf"])
        _ -> true
      end
    end)
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  # defp auth_headers(:google_drive, access_token) do
  #   [{"Authorization", "Bearer #{access_token}"}]
  # end

  defp auth_headers(:dropbox, access_token) do
    [{"Authorization", "Bearer #{access_token}"}]
  end

  defp auth_headers(:onedrive, access_token) do
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

  # defp write_file_result(content, nil, metadata) do
  #   {:ok, %{content: content, metadata: metadata}}
  # end

  # defp write_file_result(content, output_path, metadata) do
  #   case File.write(output_path, content) do
  #     :ok -> {:ok, %{path: output_path, metadata: metadata}}
  #     {:error, reason} -> {:error, "Failed to write file: #{inspect(reason)}"}
  #   end
  # end

  defp calculate_sync_stats(results, files) do
    success_count = Enum.count(results, &(&1 == :ok))

    %{
      total: length(files),
      success: success_count,
      errors: length(files) - success_count,
      results: results
    }
  end

  # ============================================================================
  # Utility Functions
  # ============================================================================

  # @spec extract_dropbox_metadata_from_headers(list(), String.t()) :: map()
  # defp extract_dropbox_metadata_from_headers(headers, file_path) do
  #   dropbox_api_result =
  #     headers
  #     |> Enum.find(fn {key, _} -> String.downcase(key) == "dropbox-api-result" end)
  #     |> case do
  #       {_, value} -> Jason.decode!(value)
  #       nil -> %{}
  #     end

  #   %{
  #     "id" => dropbox_api_result["id"] || file_path,
  #     "name" => dropbox_api_result["name"] || Path.basename(file_path),
  #     "path_display" => file_path,
  #     "size" => dropbox_api_result["size"] || 0,
  #     "client_modified" => dropbox_api_result["client_modified"],
  #     "server_modified" => dropbox_api_result["server_modified"]
  #   }
  # end

  @spec parse_size(any()) :: integer()
  defp parse_size(nil), do: 0
  defp parse_size(size) when is_binary(size), do: String.to_integer(size)
  defp parse_size(size) when is_integer(size), do: size
  defp parse_size(_), do: 0

  # @spec get_mime_type_from_extension(String.t()) :: String.t()
  # defp get_mime_type_from_extension(filename) do
  #   extension = Path.extname(String.downcase(filename))
  #   Map.get(mime_type_map(), extension, "application/octet-stream")
  # end

  # defp mime_type_map do
  #   %{
  #     ".pdf" => "application/pdf",
  #     ".doc" => "application/msword",
  #     ".docx" => "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
  #     ".xls" => "application/vnd.ms-excel",
  #     ".xlsx" => "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
  #     ".ppt" => "application/vnd.ms-powerpoint",
  #     ".pptx" => "application/vnd.openxmlformats-officedocument.presentationml.presentation",
  #     ".txt" => "text/plain",
  #     ".csv" => "text/csv",
  #     ".jpg" => "image/jpeg",
  #     ".jpeg" => "image/jpeg",
  #     ".png" => "image/png",
  #     ".gif" => "image/gif",
  #     ".zip" => "application/zip",
  #     ".rar" => "application/x-rar-compressed"
  #   }
  # end

  # @spec get_file_extension(String.t()) :: String.t()
  # defp get_file_extension(filename) do
  #   String.trim_leading(Path.extname(filename), ".")
  # end

  # @spec get_dropbox_parent_path(String.t()) :: String.t()
  # defp get_dropbox_parent_path(path_display) do
  #   case Path.dirname(path_display) do
  #     "." -> "/"
  #     "/" -> "/"
  #     parent -> parent
  #   end
  # end

  defp save_files_to_db(service, file) do
    attrs = %{
      sync_source: Atom.to_string(service),
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

  # defp save_files_to_db(:dropbox, file) do
  #   attrs = %{
  #     cloud_service: "dropbox",
  #     cloud_service_id: file["id"],
  #     name: file["name"],
  #     file_type: get_mime_type_from_extension(file["name"]),
  #     description: file["description"] || "",
  #     size: parse_size(file["size"]),
  #     created_time: file["client_modified"],
  #     modified_time: file["server_modified"],
  #     owners: nil,
  #     parents: [get_dropbox_parent_path(file["path_display"])],
  #     file_extension: get_file_extension(file["name"])
  #   }

  #   case StorageItems.create_storage_item(attrs) do
  #     {:ok, _} -> :ok
  #     error -> error
  #   end
  # end

  # defp save_files_to_db(:onedrive, file) do
  #   attrs = %{
  #     cloud_service: "onedrive",
  #     cloud_service_id: file["id"],
  #     name: file["name"],
  #     file_type: get_mime_type_from_extension(file["name"]),
  #     description: file["description"] || "",
  #     size: parse_size(file["size"]),
  #     created_time: file["createdDateTime"],
  #     modified_time: file["lastModifiedDateTime"],
  #     owners: nil,
  #     parents: [file["parentReference"]["path"]],
  #     file_extension: get_file_extension(file["name"])
  #   }

  #   case StorageItems.create_storage_item(attrs) do
  #     {:ok, _} -> :ok
  #     error -> error
  #   end
  # end

  @doc private: true
  @spec search_dropbox(String.t(), String.t(), String.t() | nil, integer()) ::
          {:ok, map()} | {:error, map()}
  defp search_dropbox(access_token, query, content_type, limit) do
    body = %{
      path: "",
      query: query,
      max_results: limit,
      file_status: "active",
      filename_only: false
    }

    body =
      if content_type do
        Map.put(body, :file_extensions, [String.trim_leading(content_type, "application/")])
      else
        body
      end

    post =
      post("#{@dropbox_base}/files/search_v2", body,
        headers: auth_headers(:dropbox, access_token)
      )

    case handle_response(post) do
      {:ok, %{"matches" => matches}} ->
        files = Enum.map(matches, & &1["metadata"])
        {:ok, %{"files" => files}}

      error ->
        error
    end
  end

  @doc private: true
  @spec search_onedrive(String.t(), String.t(), String.t() | nil, integer()) ::
          {:ok, map()} | {:error, map()}
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
        headers: auth_headers(:onedrive, access_token)
      )

    case handle_response(get) do
      {:ok, %{"value" => files}} -> {:ok, %{"files" => files}}
      error -> error
    end
  end
end
