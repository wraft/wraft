defmodule WraftDoc.CloudService.Clouds do
  @moduledoc """
  Tesla client for Google Drive API with enhanced error handling and efficient file access/download.

  Supports listing, searching, metadata fetching, exporting, and downloading files.
  """

  use Tesla
  require Logger
  alias WraftDoc.CloudService.CloudServiceAssets

  # Base URL for the Google Drive v3 API
  plug Tesla.Middleware.BaseUrl, "https://www.googleapis.com/drive/v3"

  # Default headers for all requests
  plug Tesla.Middleware.Headers, [
    {"user-agent", "wraftdoc"},
    {"accept-encoding", "gzip"}
  ]

  plug Tesla.Middleware.JSON
  plug Tesla.Middleware.FollowRedirects
  plug Tesla.Middleware.Logger
  plug Tesla.Middleware.Compression

  @mime_extensions %{
    "application/pdf" => ".pdf",
    "application/vnd.openxmlformats-officedocument.spreadsheetml.document" => ".docx",
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" => ".xlsx",
    "application/vnd.openxmlformats-officedocument.presentationml.presentation" => ".pptx",
    "text/plain" => ".txt",
    "text/csv" => ".csv",
    "image/jpeg" => ".jpg",
    "image/png" => ".png",
    "application/zip" => ".zip"
  }
  @doc """
  List files from Google Drive with optional filtering and pagination.

  ## Parameters
    - access_token: OAuth2 access token
    - query: Optional Drive query string
    - page_size: Number of items to return per page (default: 30)
    - fields: Fields to include (default: basic metadata)

  ## Example
      WraftDoc.GoogleDrive.list_files(token)
  """
  def list_files(
        access_token,
        query \\ "",
        page_size \\ 30,
        fields \\ "nextPageToken, files(id, name, mimeType, description, size, createdTime, modifiedTime, owners, parents, fileExtension)"
      ) do
    handle_response(
      get(
        "/files",
        query: [
          q: query,
          pageSize: page_size,
          fields: fields
        ],
        headers: auth_headers(access_token)
      )
    )
  end

  @doc """
  Get metadata for a specific file.

  ## Example
      WraftDoc.GoogleDrive.get_file_metadata(token, "file_id")
  """
  def get_file_metadata(
        access_token,
        file_id,
        fields \\ "id,name,mimeType,size,description,createdTime,modifiedTime,owners, parents, fileExtension"
      ) do
    handle_response(
      get("/files/#{file_id}",
        query: [fields: fields],
        headers: auth_headers(access_token)
      )
    )
  end

  @doc """
  Download a file's binary content using its file ID.
  Returns the file's content along with metadata for proper file handling.

  ## Example
      WraftDoc.GoogleDrive.download_file(token, "file_id")
  """
  def download_file(access_token, file_id, output_path \\ nil) do
    Logger.disable(self())

    result =
      with {:ok, metadata} <- get_file_metadata(access_token, file_id),
           :ok <- save_files_to_db(metadata),
           {:ok, %{status: 200, body: body}} <-
             get("/files/#{file_id}",
               query: [alt: "media"],
               headers: auth_headers(access_token)
             ) do
        if output_path do
          case File.write(output_path, body) do
            :ok -> {:ok, %{path: output_path, metadata: metadata}}
            {:error, reason} -> {:error, "Failed to write file: #{inspect(reason)}"}
          end
        else
          {:ok, %{content: body, metadata: metadata}}
        end
      else
        {:ok, %{status: status, body: body}} -> {:error, %{status: status, body: body}}
        error -> error
      end

    Logger.enable(self())
    result
  end

  def save_files_to_db(file) do
    attrs = %{
      google_drive_id: file["id"],
      name: file["name"],
      mime_type: file["mimeType"],
      description: file["description"] || "",
      size: file["size"] || 0,
      created_time: file["createdTime"],
      modified_time: file["modifiedTime"],
      owners: file["owners"],
      parents: file["parents"],
      file_extension: file["fileExtension"]
    }

    case CloudServiceAssets.create_cloud_service_assets(attrs) do
      {:ok, _record} -> :ok
      {:error, changeset} -> {:error, changeset}
    end
  end

  @spec export_file(any(), any(), any()) ::
          {:error, any()} | {:ok, %{content: any(), metadata: map()}}
  @doc """
  Export Google Workspace file to another format.
  Returns the file's content along with metadata for proper file handling.

  ## Example
      WraftDoc.GoogleDrive.export_file(token, "file_id", "application/pdf")
  """
  def export_file(access_token, file_id, mime_type) do
    with {:ok, metadata} <- get_file_metadata(access_token, file_id),
         extension = get_extension_for_mime_type(mime_type),
         {:ok, %{status: 200, body: body}} <-
           get("/files/#{file_id}/export",
             query: [mimeType: mime_type],
             headers: auth_headers(access_token) ++ [{"Accept", mime_type}]
           ) do
      updated_metadata =
        Map.merge(metadata, %{
          "exportMimeType" => mime_type,
          "exportExtension" => extension
        })

      {:ok, %{content: body, metadata: updated_metadata}}
    else
      {:ok, %{status: status, body: body}} -> {:error, %{status: status, body: body}}
      error -> error
    end
  end

  # Helper function to determine file extension from MIME type
  defp get_extension_for_mime_type(mime_type) do
    Map.get(@mime_extensions, mime_type, "")
  end

  @doc """
  Search for files by name (with optional MIME type).

  ## Example
      WraftDoc.GoogleDrive.search_files(token, "invoice", "application/pdf")
  """
  def search_files(
        access_token,
        search_term,
        mime_type \\ nil,
        page_size \\ 30,
        fields \\ "files(id,name,mimeType,description,size,owners, parents, fileExtension, createdTime, modifiedTime)"
      ) do
    query =
      if mime_type do
        "name contains '#{search_term}' and mimeType='#{mime_type}'"
      else
        "name contains '#{search_term}'"
      end

    list_files(access_token, query, page_size, fields)
  end

  @doc """
  Search for folders by name.

  ## Example
      WraftDoc.GoogleDrive.search_folders(token, "Project Docs")
  """
  def search_folders(
        access_token,
        search_term,
        page_size \\ 30,
        fields \\ "files(id,name,mimeType,description,size,createdTime,modifiedTime,owners, parents, fileExtension)"
      ) do
    query = "name contains '#{search_term}' and mimeType = 'application/vnd.google-apps.folder'"
    list_files(access_token, query, page_size, fields)
  end

  @doc """
  List all folders in Google Drive.

  ## Example
      WraftDoc.GoogleDrive.list_all_folders(token)
  """
  def list_all_folders(
        access_token,
        page_size \\ 100,
        fields \\ "nextPageToken, files(id,name,mimeType,description,size,createdTime,modifiedTime,owners, parents, fileExtension)"
      ) do
    query = "mimeType = 'application/vnd.google-apps.folder'"
    list_files(access_token, query, page_size, fields)
  end

  @doc """
  List all PDF files in Google Drive.

  ## Example
      GBook.GoogleDrive.list_all_pdfs(token)
  """
  def list_all_pdfs(
        access_token,
        page_size \\ 100,
        fields \\ "nextPageToken, files(id,name,mimeType,description,size,createdTime,modifiedTime,owners, parents, fileExtension)"
      ) do
    query = "mimeType = 'application/pdf'"
    list_files(access_token, query, page_size, fields)
  end

  @doc """
  Explore files and folders in a directory structure (like a file explorer).
  Returns folders first, then files in the specified parent folder.

  ## Example
      GBook.GoogleDrive.explorer(token, "folder_id")
  """
  def explorer(access_token, parent_id \\ "root", page_size \\ 100) do
    folders_query =
      "mimeType = 'application/vnd.google-apps.folder' and '#{parent_id}' in parents"

    files_query = "mimeType != 'application/vnd.google-apps.folder' and '#{parent_id}' in parents"

    with {:ok, %{"files" => folders}} <- list_files(access_token, folders_query, page_size),
         {:ok, %{"files" => files}} <- list_files(access_token, files_query, page_size),
         current_folder <- get_current_folder(access_token, parent_id) do
      {:ok,
       %{
         "current_folder" => current_folder,
         "folders" => folders,
         "files" => files
       }}
    else
      {:error, _} = error -> error
    end
  end

  defp get_current_folder(_access_token, "root"), do: %{"id" => "root", "name" => "My Drive"}

  defp get_current_folder(access_token, parent_id) do
    case get_file_metadata(access_token, parent_id) do
      {:ok, metadata} -> metadata
      _ -> %{"id" => parent_id, "name" => "Unknown Folder"}
    end
  end

  @doc """
  Build a breadcrumb path to a folder.

  ## Example
      GBook.GoogleDrive.folder_path(token, "folder_id")
  """
  def folder_path(access_token, folder_id) do
    path = get_folder_path(access_token, folder_id)
    {:ok, %{"path" => path}}
  end

  # Recursively build the path to a folder
  defp get_folder_path(_access_token, "root"), do: [%{"id" => "root", "name" => "My Drive"}]

  defp get_folder_path(access_token, folder_id) do
    case get_file_metadata(access_token, folder_id) do
      {:ok, folder} ->
        parent_id = get_parent_id(folder)

        if parent_id do
          get_folder_path(access_token, parent_id) ++
            [%{"id" => folder["id"], "name" => folder["name"]}]
        else
          [
            %{"id" => "root", "name" => "My Drive"},
            %{"id" => folder["id"], "name" => folder["name"]}
          ]
        end

      _ ->
        [%{"id" => "root", "name" => "My Drive"}]
    end
  end

  defp get_parent_id(%{"parents" => [parent | _]}), do: parent
  defp get_parent_id(_), do: nil

  # Standardized response handler
  defp handle_response({:ok, %{status: 200, body: body}}), do: {:ok, body}

  defp handle_response({:ok, %{status: status, body: body}}),
    do: {:error, %{status: status, body: body}}

  defp handle_response({:error, _} = error), do: error

  # Auth headers helper
  defp auth_headers(access_token) do
    [
      {"Authorization", "Bearer #{access_token}"},
      {"Accept-Encoding", "gzip"}
    ]
  end
end
