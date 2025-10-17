defmodule WraftDoc.CloudImport.Providers.GoogleDrive do
  @moduledoc """
  Google Drive implementation of the cloud storage provider.

  This module implements the CloudProvider behavior to interact with Google Drive APIs,
  providing functionality to list files, folders, download content, and sync metadata
  to the local database.

  ## Usage

      # List all files
      GoogleDrive.list_all_files(access_token, %{"page_size" => 100})

      # Download a file
      GoogleDrive.download_file(access_token, file_id, "/path/to/save")

      # Sync files to database
      GoogleDrive.sync_files_to_db(access_token, %{}, org_id)

  ## Configuration

  The module uses Google Drive API v3 with the following endpoints:
  - Files API: https://www.googleapis.com/drive/v3/files
  - Export API: https://www.googleapis.com/drive/v3/files/{fileId}/export
  """

  use WraftDoc.CloudImport.Providers, base_url: "https://www.googleapis.com/drive/v3"

  @doc """
  Lists all files from Google Drive with pagination support.

  ## Parameters

    * `access_token` - Valid Google Drive access token
    * `params` - Options map containing:
      * `"page_size"` - Number of files per page (default: 1000)
      * `"query"` - Google Drive query string for filtering
      * `"page_token"` - Token for pagination

  ## Returns

    * `{:ok, %{"files" => [google_file()], "nextPageToken" => String.t() | nil}}`
    * `{:error, %{status: integer(), body: any()}}`

  ## Examples

      iex> GoogleDrive.list_all_files(token, %{"page_size" => 50})
      {:ok, %{"files" => [...], "nextPageToken" => "..."}}

      iex> GoogleDrive.list_all_files(token, %{"query" => "mimeType='application/pdf'"})
      {:ok, %{"files" => [...]}}
  """
  @spec list_all_files(String.t(), map()) :: {:ok, map()} | {:error, map()}
  def list_all_files(access_token, params) when is_binary(access_token) and is_map(params) do
    page_size = Map.get(params, "page_size", 1000)
    query = Map.get(params, "query", "")
    page_token = Map.get(params, "page_token")

    fields =
      "nextPageToken,files(id,name,mimeType,description,size,createdTime,modifiedTime,owners,parents,fileExtension)"

    query_params = %{
      pageSize: page_size,
      fields: fields,
      q: query
    }

    query_params =
      if page_token, do: Map.put(query_params, :pageToken, page_token), else: query_params

    "#{@base_url}/files"
    |> get(
      query: query_params,
      headers: auth_headers(access_token)
    )
    |> handle_response()
  end

  @doc """
  Recursively lists all files from Google Drive, handling pagination automatically.

  ## Parameters

    * `access_token` - Valid Google Drive access token
    * `params` - Options map (same as list_all_files/2)
    * `acc` - Accumulator for recursive calls (default: [])

  ## Returns

    * `{:ok, [google_file()]}`
    * `{:error, %{status: integer(), body: any()}}`
  """
  @spec list_all_files_recursive(String.t(), map(), list()) :: {:ok, map()} | {:error, map()}
  def list_all_files_recursive(access_token, params, acc \\ []) do
    access_token
    |> list_all_files(params)
    |> case do
      {:ok, %{"files" => files, "nextPageToken" => next_token}} ->
        new_params = Map.put(params, "page_token", next_token)
        list_all_files_recursive(access_token, new_params, acc ++ files)

      {:ok, %{"files" => files}} ->
        {:ok, %{"files" => acc ++ files}}

      error ->
        error
    end
  end

  @doc """
  Retrieves metadata for a specific file from Google Drive.

  ## Parameters

    * `access_token` - Valid Google Drive access token
    * `file_id` - Google Drive file ID

  ## Returns

    * `{:ok, google_file()}`
    * `{:error, %{status: integer(), body: any()}}`
  """
  @spec get_file_metadata(String.t(), String.t()) :: {:ok, map()} | {:error, map()}
  def get_file_metadata(access_token, file_id)
      when is_binary(access_token) and is_binary(file_id) do
    fields =
      "id,name,mimeType,size,description,createdTime,modifiedTime,owners,parents,fileExtension"

    "#{@base_url}/files/#{file_id}"
    |> get(
      query: [fields: fields],
      headers: auth_headers(access_token)
    )
    |> handle_response()
  end

  @spec get_files_metadata(String.t(), list(String.t())) :: {:ok, list()}
  def get_files_metadata(access_token, file_ids) when is_list(file_ids) do
    file_ids
    |> Enum.map(fn file_id ->
      case get_file_metadata(access_token, file_id) do
        {:ok, metadata} -> metadata
        {:error, _reason} -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> then(&{:ok, &1})
  end

  @doc """
  Lists all PDF files from Google Drive.

  ## Parameters

    * `access_token` - Valid Google Drive access token
    * `params` - Options including page_size (default: 1000)

  ## Returns

    * `{:ok, %{"files" => [google_file()], "nextPageToken" => String.t() | nil}}`
    * `{:error, %{status: integer(), body: any()}}`
  """
  @spec list_all_pdfs(String.t(), map()) :: {:ok, map()} | {:error, map()}
  def list_all_pdfs(access_token, params \\ %{}) do
    page_size = Map.get(params, "page_size", 1000)

    "#{@base_url}/files"
    |> get(
      query: [
        q: "mimeType = 'application/pdf'",
        pageSize: page_size,
        fields: "nextPageToken,files(id,name,mimeType,size,modifiedTime,webViewLink)"
      ],
      headers: auth_headers(access_token)
    )
    |> handle_response()
  end

  @doc """
  Searches for files in Google Drive based on query parameters.

  ## Parameters

    * `access_token` - Valid Google Drive access token
    * `params` - Search parameters:
      * `"query"` - Search query string
      * `"content_type"` - MIME type filter
      * `"limit"` - Maximum number of results (default: 100)

  ## Returns

    * `{:ok, %{"files" => [google_file()]}}`
    * `{:error, %{status: integer(), body: any()}}`
  """
  @spec search_files(String.t(), map()) :: {:ok, map()} | {:error, map()}
  def search_files(access_token, params) when is_binary(access_token) do
    # Convert params to map if it's a keyword list
    params = if Keyword.keyword?(params), do: Map.new(params), else: params

    query = Map.get(params, "query", "") || Map.get(params, :query, "")
    content_type = Map.get(params, "content_type") || Map.get(params, :content_type)
    limit = Map.get(params, "limit", 100) || Map.get(params, :limit, 100)

    search_google_drive(access_token, query, content_type, limit)
  end

  @doc """
  Downloads a file from Google Drive.

  ## Parameters

    * `access_token` - Valid Google Drive access token
    * `file_id` - Google Drive file ID
    * `output_path` - Optional path to save the file (if nil, returns content in memory)

  ## Returns

    * `{:ok, %{content: binary(), metadata: google_file()}}` - when output_path is nil
    * `{:ok, %{path: String.t(), metadata: google_file()}}` - when file is saved
    * `{:error, String.t() | %{status: integer(), body: any()}}`
  """
  @spec download_file(Ecto.UUID.t(), String.t(), Ecto.UUID.t(), String.t()) ::
          {:ok, map()} | {:error, map()}
  def download_file(user_id, file_id, organisation_id, folder_id) do
    with {:ok, access_token} <-
           Integrations.get_latest_token(
             %User{id: user_id, current_org_id: organisation_id},
             "google_drive"
           ),
         {:ok, metadata} <- get_file_metadata(access_token, file_id),
         %StorageItem{} = _storage_item <-
           StorageItems.get_folder(folder_id, organisation_id),
         {:ok, %{status: 200, body: body}} <-
           get("#{@base_url}/files/#{file_id}",
             query: [alt: "media"],
             headers: auth_headers(access_token)
           ) do
      write_file_result(body, nil, metadata)
    else
      {:ok, %{status: 401, body: body}} ->
        {:error, %{status: 403, body: body}}

      {:ok, %{status: status, body: body}} ->
        {:error, %{status: status, body: body}}

      error ->
        error
    end
  end

  @doc """
  Lists all folders from Google Drive.

  ## Parameters

    * `access_token` - Valid Google Drive access token
    * `params` - Options including:
      * `"page_size"` - Number of folders per page (default: 100)
      * `"parent_id"` - Parent folder ID (default: "root")

  ## Returns

    * `{:ok, %{"files" => [google_folder()], "nextPageToken" => String.t() | nil}}`
    * `{:error, %{status: integer(), body: any()}}`
  """
  @spec list_all_folders(String.t(), map()) :: {:ok, map()} | {:error, map()}
  def list_all_folders(access_token, params) when is_binary(access_token) and is_map(params) do
    page_size = Map.get(params, "page_size", 100)
    parent_id = Map.get(params, "parent_id", "root")

    query =
      if parent_id == "root" do
        "mimeType = 'application/vnd.google-apps.folder'"
      else
        "mimeType = 'application/vnd.google-apps.folder' and '#{parent_id}' in parents"
      end

    fields =
      "nextPageToken, files(id, name, mimeType, createdTime, modifiedTime, owners, parents)"

    "#{@base_url}/files"
    |> get(
      query: [
        pageSize: page_size,
        fields: fields,
        q: query
      ],
      headers: auth_headers(access_token)
    )
    |> handle_response()
  end

  @doc """
  Searches for folders in Google Drive by name.

  ## Parameters

    * `access_token` - Valid Google Drive access token
    * `params` - Search parameters:
      * `"query"` - Folder name search query
      * `"page_size"` - Number of results per page (default: 100)

  ## Returns

    * `{:ok, %{"files" => [google_folder()], "nextPageToken" => String.t() | nil}}`
    * `{:error, %{status: integer(), body: any()}}`
  """
  @spec search_folders(String.t(), map()) :: {:ok, map()} | {:error, map()}
  def search_folders(access_token, params) when is_binary(access_token) do
    query = Map.get(params, "query", "")
    page_size = Map.get(params, "page_size", 100)

    search_query =
      if query == "" do
        "mimeType = 'application/vnd.google-apps.folder'"
      else
        "mimeType = 'application/vnd.google-apps.folder' and name contains '#{query}'"
      end

    fields =
      "nextPageToken, files(id, name, mimeType, createdTime, modifiedTime, owners, parents)"

    "#{@base_url}/files"
    |> get(
      query: [
        pageSize: page_size,
        fields: fields,
        q: search_query
      ],
      headers: auth_headers(access_token)
    )
    |> handle_response()
  end

  @doc """
  Lists files within a specific folder in Google Drive.

  ## Parameters

    * `access_token` - Valid Google Drive access token
    * `folder_id` - Google Drive folder ID
    * `params` - Options including:
      * `"page_size"` - Number of files per page (default: 100)
      * `"file_type"` - Filter by file type ("pdf", "image", "document", "all")

  ## Returns

    * `{:ok, %{"files" => [google_file()], "nextPageToken" => String.t() | nil}}`
    * `{:error, %{status: integer(), body: any()}}`
  """
  @spec list_files_in_folder(String.t(), String.t(), map()) :: {:ok, map()} | {:error, map()}
  def list_files_in_folder(access_token, folder_id, params)
      when is_binary(access_token) and is_binary(folder_id) do
    page_size = Map.get(params, "page_size", 100)
    file_type = Map.get(params, "file_type", "all")

    base_query = "'#{folder_id}' in parents and trashed = false"

    query =
      case file_type do
        "pdf" ->
          "#{base_query} and mimeType = 'application/pdf'"

        "image" ->
          "#{base_query} and (mimeType contains 'image/')"

        "document" ->
          "#{base_query} and (mimeType contains 'document' or mimeType contains 'text')"

        _ ->
          base_query
      end

    fields =
      "nextPageToken, files(id, name, mimeType, description, size, createdTime, modifiedTime, owners, parents, fileExtension, webViewLink)"

    "#{@base_url}/files"
    |> get(
      query: [
        pageSize: page_size,
        fields: fields,
        q: query
      ],
      headers: auth_headers(access_token)
    )
    |> handle_response()
  end

  @doc """
  Retrieves metadata for a specific folder from Google Drive.

  ## Parameters

    * `access_token` - Valid Google Drive access token
    * `folder_id` - Google Drive folder ID

  ## Returns

    * `{:ok, google_folder()}`
    * `{:error, %{status: integer(), body: any()}}`
  """
  @spec get_folder_metadata(String.t(), String.t()) :: {:ok, map()} | {:error, map()}
  def get_folder_metadata(access_token, folder_id)
      when is_binary(access_token) and is_binary(folder_id) do
    fields = "id,name,mimeType,createdTime,modifiedTime,owners,parents,description"

    "#{@base_url}/files/#{folder_id}"
    |> get(
      query: [fields: fields],
      headers: auth_headers(access_token)
    )
    |> handle_response()
  end

  def setup_sync_folder(repository) do
    case StorageItems.get_sync_folder("google_drive_files", repository.organisation_id) do
      nil ->
        %{
          "name" => "google_drive_files",
          "path" => "/google_drive_files",
          "item_type" => "folder",
          "mime_type" => "inode/directory",
          "size" => 0,
          "depth_level" => 1,
          "materialized_path" => "/google_drive_files",
          "creator_id" => repository.creator_id,
          "organisation_id" => repository.organisation_id,
          "repository_id" => repository.id
        }
        |> StorageItems.create_storage_item()
        |> case do
          {:ok, storage_item} -> {:ok, storage_item}
          {:error, reason} -> {:error, "Failed to create sync folder: #{reason}"}
        end

      storage_item ->
        {:ok, storage_item}
    end
  end

  # TODO add spec and doc.
  def sync_import_files_to_db(
        access_token,
        %{"file_ids" => file_ids},
        %{current_org_id: organisation_id},
        %StorageItem{materialized_path: path} = folder_item
      ) do
    with %{id: repository_id} = _repository <- Storage.get_latest_repository(organisation_id),
         {:ok, files} <-
           get_files_metadata(
             access_token,
             file_ids
           ) do
      saved_files =
        files
        |> Enum.map(fn file ->
          case save_files_to_db(file, repository_id, folder_item, organisation_id, path, %{
                 "upload_status" => "processing"
               }) do
            {:ok, saved} -> saved
            {:error, _reason} -> nil
          end
        end)
        |> Enum.reject(&is_nil/1)

      {:ok, saved_files}
    end
  end

  defp build_storage_attrs(
         file,
         repository_id,
         %{id: parent_folder_id, depth_level: depth_level} = _parent_folder,
         organisation_id,
         base_path,
         optional_param
       ) do
    relative_path =
      case file["pathDisplay"] do
        nil -> ""
        "" -> ""
        path -> path
      end

    final_path = Path.join(base_path, relative_path)

    Map.merge(
      %{
        "sync_source" => "google_drive",
        "external_id" => file["id"],
        "name" => file["name"],
        "display_name" => file["name"],
        "depth_level" =>
          if parent_folder_id do
            depth_level + 1
          else
            1
          end,
        "organisation_id" => organisation_id,
        "parent_id" => parent_folder_id,
        "repository_id" => repository_id,
        "path" => "/#{file["name"]}",
        "materialized_path" => final_path <> "/#{file["name"]}",
        "mime_type" => file["mimeType"],
        "item_type" => "external file",
        "metadata" => %{description: file["description"] || ""},
        "size" => parse_size(file["size"]),
        "modified_time" => file["modifiedTime"],
        "external_metadata" => %{
          "owner" => file["owners"],
          "created_time" => file["createdTime"],
          "parents" => file["parents"]
        },
        "file_extension" => file["fileExtension"] || get_google_file_extension(file["mimeType"])
      },
      optional_param
    )
  end

  defp get_google_file_extension(mime_type) do
    case mime_type do
      "application/vnd.google-apps.spreadsheet" -> "xlsx"
      "application/vnd.google-apps.document" -> "docx"
      "application/vnd.google-apps.presentation" -> "pptx"
      _ -> ""
    end
  end

  defp search_google_drive(access_token, query, content_type, limit) do
    safe_query = String.replace(query, "'", "''")

    conditions =
      [
        "trashed = false",
        if(safe_query != "", do: "name contains '#{safe_query}'"),
        if(content_type, do: "mimeType = '#{content_type}'")
      ]
      |> Enum.reject(&is_nil/1)
      |> Enum.join(" and ")

    "#{@base_url}/files"
    |> get(
      query: [
        q: conditions,
        pageSize: limit,
        fields: "files(id,name,mimeType,modifiedTime,size,webViewLink)"
      ],
      headers: auth_headers(access_token)
    )
    |> handle_response()
  end
end
