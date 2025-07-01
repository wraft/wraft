defmodule WraftDoc.CloudImport.Providers.Dropbox do
  @moduledoc """
  Dropbox cloud storage provider implementation.
  Provides access to Dropbox files and folders through the Dropbox API v2.
  """

  use WraftDoc.CloudImport.Providers, base_url: "https://api.dropboxapi.com/2"

  @content_base "https://content.dropboxapi.com/2"

  @doc """
  List all files from Dropbox.

  ## Parameters
  - `access_token`: OAuth2 access token for Dropbox API
  - `params`: Map or keyword list of options:
    - `:path`: Path to list files from (default: "")
    - `:recursive`: Boolean for recursive listing (default: false)
    - `:limit`: Maximum number of files to return

  ## Examples
      iex> list_all_files("token123", %{path: "/documents", recursive: true})
      {:ok, %{"files" => [%{"name" => "report.pdf", ...}, ...]}}

  ## Returns
  - `{:ok, %{"files" => list()}}`: Success with files list
  - `{:error, map()}`: Error with status and body information
  """
  @impl true
  @spec list_all_files(String.t(), map() | keyword()) :: {:ok, map()} | {:error, map()}
  def list_all_files(access_token, params) do
    opts = normalize_params(params)
    path = Map.get(opts, :path, "")
    recursive = Map.get(opts, :recursive, false)

    body = %{
      path: path,
      recursive: recursive,
      include_media_info: true,
      include_deleted: false
    }

    "#{@base_url}/files/list_folder"
    |> post(body, headers: auth_headers(access_token))
    |> handle_response()
    |> case do
      {:ok, %{"entries" => entries}} ->
        files = Enum.filter(entries, &(&1[".tag"] == "file"))
        {:ok, %{"files" => files}}

      error ->
        error
    end
  end

  @doc """
  Recursively list all files from Dropbox with pagination support.

  ## Parameters
  - `access_token`: OAuth2 access token for Dropbox API
  - `params`: Map or keyword list of options (same as list_all_files/2)
  - `acc`: Accumulator for recursive calls (default: [])

  ## Returns
  - `{:ok, list()}`: Success with complete files list
  - `{:error, map()}`: Error with status and body information
  """
  @impl true
  @spec list_all_files_recursive(String.t(), map() | keyword(), list()) ::
          {:ok, list()} | {:error, map()}
  def list_all_files_recursive(access_token, params, acc \\ []) do
    case list_all_files(access_token, params) do
      {:ok, %{"files" => files, "has_more" => true, "cursor" => cursor}} ->
        continue_params = %{cursor: cursor}

        access_token
        |> list_folder_continue(continue_params)
        |> case do
          {:ok, %{"files" => more_files}} ->
            list_all_files_recursive(access_token, continue_params, acc ++ files ++ more_files)

          error ->
            error
        end

      {:ok, %{"files" => files}} ->
        {:ok, acc ++ files}

      error ->
        error
    end
  end

  @doc """
  Get file metadata from Dropbox.

  ## Parameters
  - `access_token`: OAuth2 access token for Dropbox API
  - `file_path`: Path to the file in Dropbox

  ## Examples
      iex> get_file_metadata("token123", "/documents/report.pdf")
      {:ok, %{"name" => "report.pdf", "size" => 1024, ...}}

  ## Returns
  - `{:ok, map()}`: Success with file metadata
  - `{:error, map()}`: Error with status and body information
  """
  @impl true
  @spec get_file_metadata(String.t(), String.t()) :: {:ok, map()} | {:error, map()}
  def get_file_metadata(access_token, file_path) do
    body = %{path: file_path}

    "#{@base_url}/files/get_metadata"
    |> post(body, headers: auth_headers(access_token))
    |> handle_response()
  end

  @doc """
  List all PDF files from Dropbox.

  ## Parameters
  - `access_token`: OAuth2 access token for Dropbox API
  - `params`: Map or keyword list of options:
    - `:path`: Path to search for PDFs (default: "")
    - `:limit`: Maximum number of PDFs to return (default: 2000)
    - `:recursive`: Boolean for recursive search (default: false)

  ## Examples
      iex> list_all_pdfs("token123", %{path: "/documents", recursive: true})
      {:ok, %{"files" => [%{"name" => "report.pdf", ...}, ...]}}

  ## Returns
  - `{:ok, %{"files" => list()}}`: Success with PDF files list
  - `{:error, map()}`: Error with status and body information
  """
  @impl true
  @spec list_all_pdfs(String.t(), map() | keyword()) :: {:ok, map()} | {:error, map()}
  def list_all_pdfs(access_token, params) do
    opts = normalize_params(params)
    path = Map.get(opts, :path, "")
    limit = Map.get(opts, :limit, 2000)
    recursive = Map.get(opts, :recursive, false)

    body = %{
      path: path,
      limit: limit,
      recursive: recursive,
      include_media_info: false,
      include_deleted: false
    }

    "#{@base_url}/files/list_folder"
    |> post(body, headers: auth_headers(access_token))
    |> handle_response()
    |> case do
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
  Search for files in Dropbox.

  ## Parameters
  - `access_token`: OAuth2 access token for Dropbox API
  - `params`: Map or keyword list of options:
    - `:query`: Search query string
    - `:content_type`: Filter by content type (e.g., "application/pdf")
    - `:limit`: Maximum results to return (default: 100)

  ## Examples
      iex> search_files("token123", %{query: "annual report", content_type: "application/pdf"})
      {:ok, %{"files" => [...]}}

  ## Returns
  - `{:ok, %{"files" => list()}}`: Success with matching files
  - `{:error, map()}`: Error with status and body information
  """
  @impl true
  @spec search_files(String.t(), map() | keyword()) :: {:ok, map()} | {:error, map()}
  def search_files(access_token, params) do
    opts = normalize_params(params)

    query = Map.get(opts, :query, "")
    content_type = Map.get(opts, :content_type)
    limit = Map.get(opts, :limit, 100)

    search_dropbox_files(access_token, query, content_type, limit)
  end

  @doc """
  Download a file from Dropbox.

  ## Parameters
  - `access_token`: OAuth2 access token for Dropbox API
  - `file_path`: Path to the file in Dropbox
  - `output_path`: Optional local path to save the file (if nil, returns content)

  ## Examples
      iex> download_file("token123", "/documents/report.pdf", "/tmp/report.pdf")
      {:ok, %{path: "/tmp/report.pdf", metadata: %{...}}}

      iex> download_file("token123", "/documents/report.pdf", nil)
      {:ok, %{content: <<binary_data>>, metadata: %{...}}}

  ## Returns
  - `{:ok, map()}`: Success with file content or path and metadata
  - `{:error, map()}`: Error with status and body information
  """
  @impl true
  @spec download_file(String.t(), String.t(), String.t() | nil) :: {:ok, map()} | {:error, map()}
  def download_file(access_token, file_path, output_path \\ nil) do
    headers =
      auth_headers(access_token) ++ [{"Dropbox-API-Arg", Jason.encode!(%{path: file_path})}]

    "#{@content_base}/files/download"
    |> post("", headers: headers)
    |> case do
      {:ok, %{status: status, body: content, headers: response_headers}}
      when status in 200..299 ->
        metadata = extract_dropbox_metadata_from_headers(response_headers, file_path)
        write_file_result(content, output_path, metadata)

      {:ok, %{status: status, body: body}} ->
        {:error, %{status: status, body: body}}

      {:error, reason} ->
        {:error, %{status: 500, body: reason}}
    end
  end

  @doc """
  List all folders from Dropbox.

  ## Parameters
  - `access_token`: OAuth2 access token for Dropbox API
  - `params`: Map or keyword list of options:
    - `:path`: Path to list folders from (default: "")
    - `:recursive`: Boolean for recursive listing (default: false)

  ## Examples
      iex> list_all_folders("token123", %{path: "/work", recursive: true})
      {:ok, %{"folders" => [%{"name" => "projects", "path_display" => "/work/projects", ...}, ...]}}

  ## Returns
  - `{:ok, %{"folders" => list()}}`: Success with folders list
  - `{:error, map()}`: Error with status and body information
  """
  @impl true
  @spec list_all_folders(String.t(), map() | keyword()) :: {:ok, map()} | {:error, map()}
  def list_all_folders(access_token, params) do
    opts = normalize_params(params)
    path = Map.get(opts, :path, "")
    recursive = Map.get(opts, :recursive, false)

    body = %{
      path: path,
      recursive: recursive,
      include_media_info: false,
      include_deleted: false
    }

    "#{@base_url}/files/list_folder"
    |> post(body, headers: auth_headers(access_token))
    |> handle_response()
    |> case do
      {:ok, %{"entries" => entries}} ->
        folders = Enum.filter(entries, &(&1[".tag"] == "folder"))
        {:ok, %{"folders" => folders}}

      error ->
        error
    end
  end

  @doc """
  Search for folders in Dropbox.

  ## Parameters
  - `access_token`: OAuth2 access token for Dropbox API
  - `params`: Map or keyword list of options:
    - `:query`: Search query string (default: "")
    - `:max_results`: Maximum results to return (default: 100)

  ## Examples
      iex> search_folders("token123", %{query: "documents", max_results: 25})
      {:ok, %{"folders" => [%{"name" => "My Documents", ...}, ...]}}

  ## Returns
  - `{:ok, %{"folders" => list()}}`: Success with matching folders
  - `{:error, map()}`: Error with status and body information
  """
  @impl true
  @spec search_folders(String.t(), map() | keyword()) :: {:ok, map()} | {:error, map()}
  def search_folders(access_token, params) do
    opts = normalize_params(params)

    query = Map.get(opts, :query, "")
    max_results = Map.get(opts, :max_results, 100)

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

    "#{@base_url}/files/search_v2"
    |> post(body, headers: auth_headers(access_token))
    |> handle_response()
    |> case do
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
  List files in a specific folder.

  ## Parameters
  - `access_token`: OAuth2 access token for Dropbox API
  - `folder_path`: Path to the folder in Dropbox
  - `params`: Map or keyword list of options:
    - `:recursive`: Boolean for recursive listing (default: false)
    - `:limit`: Maximum number of files to return

  ## Examples
      iex> list_files_in_folder("token123", "/documents", %{recursive: false})
      {:ok, %{"files" => [%{"name" => "file1.pdf", ...}, ...]}}

  ## Returns
  - `{:ok, %{"files" => list()}}`: Success with files in folder
  - `{:error, map()}`: Error with status and body information
  """
  @impl true
  @spec list_files_in_folder(String.t(), String.t(), map() | keyword()) ::
          {:ok, map()} | {:error, map()}
  def list_files_in_folder(access_token, folder_path, params) do
    params
    |> normalize_params()
    |> Map.put(:path, folder_path)
    |> then(&list_all_files(access_token, &1))
  end

  @doc """
  Get folder metadata from Dropbox.

  ## Parameters
  - `access_token`: OAuth2 access token for Dropbox API
  - `folder_path`: Path to the folder in Dropbox

  ## Examples
      iex> get_folder_metadata("token123", "/work/projects")
      {:ok, %{"name" => "projects", "path_display" => "/work/projects", ".tag" => "folder", ...}}

  ## Returns
  - `{:ok, map()}`: Success with folder metadata
  - `{:error, map()}`: Error with status and body information
  """
  @impl true
  @spec get_folder_metadata(String.t(), String.t()) :: {:ok, map()} | {:error, map()}
  def get_folder_metadata(access_token, folder_path) do
    body = %{path: folder_path}

    "#{@base_url}/files/get_metadata"
    |> post(body, headers: auth_headers(access_token))
    |> handle_response()
  end

  defp normalize_params(params) when is_list(params), do: Map.new(params)
  defp normalize_params(params) when is_map(params), do: params

  defp search_dropbox_files(access_token, query, content_type, limit) do
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

    "#{@base_url}/files/search_v2"
    |> post(body, headers: auth_headers(access_token))
    |> handle_response()
    |> case do
      {:ok, %{"matches" => matches}} ->
        files = Enum.map(matches, & &1["metadata"])
        {:ok, %{"files" => files}}

      error ->
        error
    end
  end

  defp list_folder_continue(access_token, %{cursor: cursor}) do
    body = %{cursor: cursor}

    "#{@base_url}/files/list_folder/continue"
    |> post(body, headers: auth_headers(access_token))
    |> handle_response()
    |> case do
      {:ok, %{"entries" => entries}} ->
        files = Enum.filter(entries, &(&1[".tag"] == "file"))
        {:ok, %{"files" => files}}

      error ->
        error
    end
  end

  defp extract_dropbox_metadata_from_headers(headers, file_path) do
    dropbox_api_result =
      headers
      |> Enum.find(fn {key, _} -> String.downcase(key) == "dropbox-api-result" end)
      |> case do
        {_, value} -> Jason.decode!(value)
        nil -> %{}
      end

    %{
      "id" => dropbox_api_result["id"] || file_path,
      "name" => dropbox_api_result["name"] || Path.basename(file_path),
      "path_display" => file_path,
      "size" => dropbox_api_result["size"] || 0,
      "client_modified" => dropbox_api_result["client_modified"],
      "server_modified" => dropbox_api_result["server_modified"]
    }
  end

  defp build_storage_attrs(file, org_id) do
    file_name = Map.get(file, "name", "")

    %{
      sync_source: "dropbox",
      external_id: file["id"],
      name: file_name,
      path: get_display_path(file),
      materalized_path: get_display_path(file),
      mime_type: get_mime_type(file, file_name),
      metadata: %{description: Map.get(file, "description", "")},
      size: parse_size(file["size"]),
      modified_time: get_modified_time(file),
      external_metadata: build_external_metadata(file),
      file_extension: get_file_extension(file_name),
      org_id: org_id
    }
  end

  defp get_display_path(file),
    do: Map.get(file, "path_display") || Map.get(file, "pathDisplay", "")

  defp get_mime_type(file, file_name),
    do: Map.get(file, "mimeType") || get_mime_type_from_extension(file_name)

  defp get_modified_time(file),
    do: Map.get(file, "server_modified") || Map.get(file, "modifiedTime")

  defp build_external_metadata(file) do
    %{
      owner: Map.get(file, "owners", []),
      created_time: Map.get(file, "client_modified") || Map.get(file, "createdTime"),
      parents: Map.get(file, "parents", []),
      path_lower: file["path_lower"]
    }
  end

  defp get_mime_type_from_extension(filename) do
    filename
    |> String.downcase()
    |> Path.extname()
    |> then(&Map.get(mime_type_map(), &1, "application/octet-stream"))
  end

  defp mime_type_map do
    %{
      ".pdf" => "application/pdf",
      ".doc" => "application/msword",
      ".docx" => "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
      ".xls" => "application/vnd.ms-excel",
      ".xlsx" => "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      ".ppt" => "application/vnd.ms-powerpoint",
      ".pptx" => "application/vnd.openxmlformats-officedocument.presentationml.presentation",
      ".txt" => "text/plain",
      ".csv" => "text/csv",
      ".jpg" => "image/jpeg",
      ".jpeg" => "image/jpeg",
      ".png" => "image/png",
      ".gif" => "image/gif",
      ".zip" => "application/zip",
      ".rar" => "application/x-rar-compressed"
    }
  end

  defp get_file_extension(filename), do: String.trim_leading(Path.extname(filename), ".")
end
