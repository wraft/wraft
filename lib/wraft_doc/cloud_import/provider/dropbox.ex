defmodule WraftDoc.CloudImport.Dropbox do
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
  # @onedrive_base "https://graph.microsoft.com/v1.0"

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
  def list_all_files(access_token, params) do
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
      post("#{@dropbox_base}/files/list_folder", body, headers: auth_headers(access_token))

    case handle_response(post) do
      {:ok, %{"entries" => entries}} ->
        files = Enum.filter(entries, &(&1[".tag"] == "file"))
        {:ok, %{"files" => files}}

      error ->
        error
    end
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

  def get_file_metadata(access_token, file_path) do
    body = %{path: file_path}

    handle_response(
      post("#{@dropbox_base}/files/get_metadata", body, headers: auth_headers(access_token))
    )
  end

  def list_all_pdfs(access_token, params) do
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
      post("#{@dropbox_base}/files/list_folder", body, headers: auth_headers(access_token))

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
    action = String.replace("download_dropbox_to_minio", "_drive", "")

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
  def search_files(access_token, opts) do
    # Convert opts to map if it's a keyword list
    opts = if Keyword.keyword?(opts), do: Map.new(opts), else: opts

    query = Map.get(opts, "query", "") || Map.get(opts, :query, "")
    content_type = Map.get(opts, "content_type") || Map.get(opts, :content_type)
    limit = Map.get(opts, "limit", 100) || Map.get(opts, :limit, 100)

    search_dropbox(access_token, query, content_type, limit)
  end

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
  def list_all_folders(access_token, params) do
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
      post("#{@dropbox_base}/files/list_folder", body, headers: auth_headers(access_token))

    case handle_response(post) do
      {:ok, %{"entries" => entries}} ->
        folders = Enum.filter(entries, &(&1[".tag"] == "folder"))
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
  def search_folders(access_token, opts) do
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
      post("#{@dropbox_base}/files/search_v2", body, headers: auth_headers(access_token))

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
  def get_folder_metadata(access_token, folder_path) do
    body = %{path: folder_path}

    handle_response(
      post("#{@dropbox_base}/files/get_metadata", body, headers: auth_headers(access_token))
    )
  end

  # @spec filter_files_by_type(list(map()), String.t()) :: list(map())
  # defp filter_files_by_type(files, "all"), do: files

  # defp filter_files_by_type(files, file_type) do
  #   Enum.filter(files, fn file ->
  #     name = String.downcase(file["name"] || "")

  #     case file_type do
  #       "pdf" -> String.ends_with?(name, ".pdf")
  #       "image" -> String.ends_with?(name, [".jpg", ".jpeg", ".png", ".gif", ".bmp"])
  #       "document" -> String.ends_with?(name, [".doc", ".docx", ".txt", ".rtf"])
  #       _ -> true
  #     end
  #   end)
  # end

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
      post("#{@dropbox_base}/files/search_v2", body, headers: auth_headers(access_token))

    case handle_response(post) do
      {:ok, %{"matches" => matches}} ->
        files = Enum.map(matches, & &1["metadata"])
        {:ok, %{"files" => files}}

      error ->
        error
    end
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

  defp save_files_to_db(file) do
    attrs = %{
      sync_source: "dropbox",
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
