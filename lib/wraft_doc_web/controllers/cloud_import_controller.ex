defmodule WraftDocWeb.Api.V1.CloudImportController do
  @moduledoc """
  Controller for handling cloud provider interactions with Google Drive, Dropbox, and OneDrive.
  Provides fully independent endpoint implementations for each provider.
  """
  use WraftDocWeb, :controller
  use PhoenixSwagger

  alias WraftDoc.CloudImport.Providers.Dropbox
  alias WraftDoc.CloudImport.Providers.GoogleDrive, as: Google
  alias WraftDoc.CloudImport.Providers.Onedrive
  alias WraftDoc.CloudImport.RepositoryCloudTokens, as: AuthTokens

  action_fallback(WraftDocWeb.FallbackController)

  require Logger

  def swagger_definitions do
    %{
      GoogleDriveFile:
        swagger_schema do
          title("Google Drive File")
          description("A file from Google Drive")

          properties do
            id(:string, "The ID of the file", required: true)
            name(:string, "Name of the file")
            mimeType(:string, "MIME type of the file")
            webViewLink(:string, "URL to view the file in Google Drive")
            webContentLink(:string, "URL to download the file content")
            size(:string, "Size of the file in bytes")
            modifiedTime(:string, "Last modified time", format: "date-time")
            createdTime(:string, "Creation time", format: "date-time")
          end

          example(%{
            "id" => "1a2b3c4d5e6f7g",
            "name" => "example.pdf",
            "mimeType" => "application/pdf",
            "webViewLink" => "https://drive.google.com/file/d/1a2b3c4d5e6f7g/view",
            "webContentLink" => "https://drive.google.com/uc?id=1a2b3c4d5e6f7g&export=download",
            "size" => "1024",
            "modifiedTime" => "2023-01-01T12:00:00Z",
            "createdTime" => "2023-01-01T10:00:00Z"
          })
        end,
      GoogleDriveFileList:
        swagger_schema do
          title("Google Drive File List")
          description("List of files from Google Drive with pagination info")

          properties do
            files(Schema.ref(:GoogleDriveFile), "List of files", type: :array)
            nextPageToken(:string, "Token for next page of results")
          end

          example(%{
            "files" => [
              %{
                "id" => "1a2b3c4d5e6f7g",
                "name" => "example.pdf"
              }
            ],
            "nextPageToken" => "ABCD1234"
          })
        end,
      GoogleDriveFolder:
        swagger_schema do
          title("Google Drive Folder")
          description("A folder from Google Drive")

          properties do
            id(:string, "The ID of the folder", required: true)
            name(:string, "Name of the folder")
            mimeType(:string, "MIME type (always 'application/vnd.google-apps.folder')")
            webViewLink(:string, "URL to view the folder in Google Drive")
            modifiedTime(:string, "Last modified time", format: "date-time")
            createdTime(:string, "Creation time", format: "date-time")
          end

          example(%{
            "id" => "1a2b3c4d5e6f7g",
            "name" => "Example Folder",
            "mimeType" => "application/vnd.google-apps.folder",
            "webViewLink" => "https://drive.google.com/drive/folders/1a2b3c4d5e6f7g",
            "modifiedTime" => "2023-01-01T12:00:00Z",
            "createdTime" => "2023-01-01T10:00:00Z"
          })
        end,
      GoogleDriveFolderList:
        swagger_schema do
          title("Google Drive Folder List")
          description("List of folders from Google Drive")

          properties do
            folders(Schema.ref(:GoogleDriveFolder), "List of folders", type: :array)
            nextPageToken(:string, "Token for next page of results")
          end

          example(%{
            "folders" => [
              %{
                "id" => "1a2b3c4d5e6f7g",
                "name" => "Example Folder"
              }
            ],
            "nextPageToken" => "ABCD1234"
          })
        end,
      DownloadRequest:
        swagger_schema do
          title("Download Request")
          description("Request to download files from Google Drive")

          properties do
            file_ids(:array, "List of file IDs to download",
              items: %Schema{type: :string},
              example: ["file1", "file2"]
            )
          end
        end,
      DownloadResponse:
        swagger_schema do
          title("Download Response")
          description("Response for file download request")

          properties do
            status(:string, "Processing status", enum: ["processing"])
            provider(:string, "Provider name", enum: ["google_drive"])
          end

          example(%{
            status: "processing",
            provider: "google_drive"
          })
        end,
      SyncResponse:
        swagger_schema do
          title("Sync Response")
          description("Response for file sync operation")

          properties do
            status(:string, "Operation status", enum: ["success"])
            sync_result(:object, "Result of sync operation")
          end

          example(%{
            status: "success",
            sync_result: %{
              files_added: 5,
              files_updated: 2,
              files_skipped: 0
            }
          })
        end
    }
  end

  swagger_path :list_gdrive_files do
    get("/clouds/google/files")
    summary("List Google Drive files")
    description("Lists all files in Google Drive with optional pagination")

    parameters do
      page_token(:query, :string, "Token for pagination", required: false)
      page_size(:query, :integer, "Number of items per page", required: false)
    end

    response(200, "OK", Schema.ref(:GoogleDriveFileList))
    response(401, "Unauthorized")
    response(500, "Internal Server Error")
  end

  @doc """
  Lists all files in Google Drive.
  # no params are required, but pagination can be handled via passing `page_token` and `page_size` params.
  """
  def list_gdrive_files(conn, params) do
    current_user = conn.assigns[:current_user]

    with token when not is_nil(token) <- AuthTokens.get_latest_token(current_user, :google_drive),
         {:ok, files} <- Google.list_all_files(token, params) do
      json(conn, %{
        "status" => "success",
        "files" => files["files"],
        "next_page_token" => files["nextPageToken"]
      })
    end
  end

  swagger_path :get_gdrive_file do
    get("/clouds/google/file/{file_id}")
    summary("Get Google Drive file metadata")
    description("Retrieves metadata for a specific file in Google Drive")

    parameters do
      file_id(:path, :string, "ID of the file to retrieve", required: true)
    end

    response(200, "OK", Schema.ref(:GoogleDriveFile))
    response(401, "Unauthorized")
    response(404, "File not found")
  end

  @doc """
  Retrieves metadata for a specific file in Google Drive.
  This endpoint requires a `file_id` parameter to identify the file.
  """
  def get_gdrive_file(conn, %{"file_id" => file_id}) do
    current_user = conn.assigns[:current_user]

    with token when not is_nil(token) <- AuthTokens.get_latest_token(current_user, :google_drive),
         {:ok, metadata} <- Google.get_file_metadata(token, file_id) do
      json(conn, %{"status" => "success", "file_metadata" => metadata})
    end
  end

  swagger_path :list_all_gdrive_pdfs do
    get("/clouds/google/pdfs")
    summary("List all PDF files in Google Drive")
    description("Lists all PDF files in Google Drive with optional pagination")

    parameters do
      page_token(:query, :string, "Token for pagination", required: false)
      page_size(:query, :integer, "Number of items per page", required: false)
    end

    response(200, "OK", Schema.ref(:GoogleDriveFileList))
    response(401, "Unauthorized")
    response(500, "Internal Server Error")
  end

  @doc """
  Lists all PDF files in Google Drive.
  # no params are required, but pagination can be handled via passing `page_token` and `page_size` params.
  """
  def list_all_gdrive_pdfs(conn, params) do
    current_user = conn.assigns[:current_user]

    with token when not is_nil(token) <- AuthTokens.get_latest_token(current_user, :google_drive),
         {:ok, pdfs} <- Google.list_all_pdfs(token, params) do
      json(conn, %{"status" => "success", "pdfs" => pdfs["files"]})
    end
  end

  swagger_path :search_gdrive_files do
    get("/clouds/google/search")
    summary("Search Google Drive files")
    description("Searches for files in Google Drive based on query parameters")

    parameters do
      query(:query, :string, "Search query", required: false)
      page_token(:query, :string, "Token for pagination", required: false)
      page_size(:query, :integer, "Number of items per page", required: false)
    end

    response(200, "OK", Schema.ref(:GoogleDriveFileList))
    response(401, "Unauthorized")
    response(500, "Internal Server Error")
  end

  @doc """
  Searches for files in Google Drive based on provided parameters.
  # no params are required, but you can pass `query` for query,
  """
  def search_gdrive_files(conn, params) do
    current_user = conn.assigns[:current_user]

    with token when not is_nil(token) <- AuthTokens.get_latest_token(current_user, :google_drive),
         {:ok, results} <- Google.search_files(token, params) do
      json(conn, %{"status" => "success", "results" => results})
    end
  end

  @doc """
  Synchronizes Google Drive files with the database.
  This endpoint fetches files from Google Drive and updates the database.
  # no params are required,
  """
  swagger_path :sync_gdrive_files do
    post("/clouds/google/sync_files")
    summary("Sync Google Drive files with database")
    description("Fetches files from Google Drive and updates the database")

    response(200, "OK", Schema.ref(:SyncResponse))
    response(401, "Unauthorized")
    response(500, "Internal Server Error")
  end

  def sync_gdrive_files(conn, params) do
    current_user = conn.assigns[:current_user]
    current_org_id = current_user.current_org_id

    with token when not is_nil(token) <- AuthTokens.get_latest_token(current_user, :google_drive),
         {:ok, result} <- Google.sync_files_to_db(token, params, current_org_id) do
      json(conn, %{"status" => "success", "sync_result" => result})
    end
  end

  swagger_path :download_gdrive_file do
    post("/clouds/google/download")
    summary("Download files from Google Drive")
    description("Schedules download of specified files from Google Drive to MinIO")

    parameters do
      file_ids(:body, Schema.ref(:DownloadRequest), "List of file IDs to download",
        required: true
      )
    end

    response(202, "Accepted", Schema.ref(:DownloadResponse))
    response(401, "Unauthorized")
    response(500, "Internal Server Error")
  end

  @doc """
  Downloads files from Google Drive based on provided file IDs.
  This endpoint accepts a list of file IDs and schedules downloads.
  # param requied ,`file_ids` should be a list of file IDs to download
  """
  def download_gdrive_file(conn, %{"file_ids" => file_ids}) do
    user = conn.assigns[:current_user]
    org_id = user.current_org_id

    with token when not is_nil(token) <- AuthTokens.get_latest_token(user, :google_drive) do
      _results =
        Google.schedule_download_to_minio(token, file_ids, org_id, %{
          user_id: user.id
        })

      conn
      |> put_status(:accepted)
      |> json(%{
        status: "processing",
        provider: "google_drive"
        # results: results
      })
    end
  end

  swagger_path :list_gdrive_folders do
    get("/clouds/google/folders")
    summary("List Google Drive folders")
    description("Lists all folders in Google Drive with optional pagination")

    parameters do
      page_token(:query, :string, "Token for pagination", required: false)
      page_size(:query, :integer, "Number of items per page", required: false)
    end

    response(200, "OK", Schema.ref(:GoogleDriveFolderList))
    response(401, "Unauthorized")
    response(500, "Internal Server Error")
  end

  @doc """
  Lists all folders in Google Drive.
  # no params are required, but pagination can be handled via passing `page_token` and `page_size` params.
  This endpoint retrieves all folders in the user's Google Drive.
  """

  def list_gdrive_folders(conn, params) do
    current_user = conn.assigns[:current_user]

    with token when not is_nil(token) <- AuthTokens.get_latest_token(current_user, :google_drive),
         {:ok, folders} <- Google.list_all_folders(token, params) do
      json(conn, %{"status" => "success", "folders" => folders["files"]})
    end
  end

  swagger_path :search_gdrive_folders do
    get("/clouds/google/folders/search")
    summary("Search Google Drive folders")
    description("Searches for folders in Google Drive based on query parameters")

    parameters do
      query(:query, :string, "Search query", required: false)
      page_token(:query, :string, "Token for pagination", required: false)
      page_size(:query, :integer, "Number of items per page", required: false)
    end

    response(200, "OK", Schema.ref(:GoogleDriveFolderList))
    response(401, "Unauthorized")
    response(500, "Internal Server Error")
  end

  @doc """
  Searches for folders in Google Drive based on provided parameters.
  # no params are required, but you can pass `query` for searching folders.
  This endpoint allows users to search for folders in their Google Drive.
  """
  def search_gdrive_folders(conn, params) do
    current_user = conn.assigns[:current_user]

    with token when not is_nil(token) <- AuthTokens.get_latest_token(current_user, :google_drive),
         {:ok, results} <- Google.search_folders(token, params) do
      json(conn, %{"status" => "success", "folders" => results["files"]})
    end
  end

  swagger_path :list_gdrive_folder_files do
    get("/clouds/google/folder/{folder_id}/files")
    summary("List files in Google Drive folder")
    description("Lists all files within a specific Google Drive folder")

    parameters do
      folder_id(:path, :string, "ID of the folder", required: true)
      page_token(:query, :string, "Token for pagination", required: false)
      page_size(:query, :integer, "Number of items per page", required: false)
    end

    response(200, "OK", Schema.ref(:GoogleDriveFileList))
    response(401, "Unauthorized")
    response(404, "Folder not found")
  end

  @doc """
  Lists all files within a specific Google Drive folder.
  # param required,  a `folder_id` parameter to identify the folder.
  It retrieves all files contained within the specified folder.
  """
  def list_gdrive_folder_files(conn, %{"folder_id" => folder_id} = params) do
    current_user = conn.assigns[:current_user]

    with token when not is_nil(token) <- AuthTokens.get_latest_token(current_user, :google_drive),
         {:ok, files} <- Google.list_files_in_folder(token, folder_id, params) do
      json(conn, %{"status" => "success", "files" => files["files"]})
    end
  end

  swagger_path :get_gdrive_folder do
    get("/clouds/google/folder/{folder_id}")
    summary("Get Google Drive folder metadata")
    description("Retrieves metadata for a specific folder in Google Drive")

    parameters do
      folder_id(:path, :string, "ID of the folder", required: true)
    end

    response(200, "OK", Schema.ref(:GoogleDriveFolder))
    response(401, "Unauthorized")
    response(404, "Folder not found")
  end

  @doc """
  Retrieves metadata for a specific folder in Google Drive.
  # param required, a `folder_id` parameter to identify the folder.
  This endpoint fetches metadata for the specified folder in Google Drive.
  """
  def get_gdrive_folder(conn, %{"folder_id" => folder_id}) do
    current_user = conn.assigns[:current_user]

    with token when not is_nil(token) <- AuthTokens.get_latest_token(current_user, :google_drive),
         {:ok, metadata} <- Google.get_folder_metadata(token, folder_id) do
      json(conn, %{"status" => "success", "folder_metadata" => metadata})
    end
  end

  # Dropbox endpoints
  @doc """
  Lists all files in Dropbox.
  """
  def list_dropbox_files(conn, params) do
    current_user = conn.assigns[:current_user]

    with token when not is_nil(token) <- AuthTokens.get_latest_token(current_user, :dropbox),
         {:ok, files} <- Dropbox.list_all_files(token, params) do
      json(conn, %{"status" => "success", "files" => files["files"]})
    end
  end

  @doc """
  Retrieves metadata for a specific file in Dropbox.
  """
  def get_dropbox_file(conn, %{"file_id" => file_id}) do
    current_user = conn.assigns[:current_user]

    with token when not is_nil(token) <- AuthTokens.get_latest_token(current_user, :dropbox),
         {:ok, metadata} <- Dropbox.get_file_metadata(token, file_id) do
      json(conn, %{"status" => "success", "file_metadata" => metadata})
    end
  end

  @doc """
  Lists all PDF files in Dropbox.
  """
  def list_all_dropbox_pdfs(conn, params) do
    current_user = conn.assigns[:current_user]

    with token when not is_nil(token) <- AuthTokens.get_latest_token(current_user, :dropbox),
         {:ok, pdfs} <- Dropbox.list_all_pdfs(token, params) do
      json(conn, %{"status" => "success", "pdfs" => pdfs["files"]})
    end
  end

  @doc """
  Searches for files in Dropbox based on provided parameters.
  """
  def search_dropbox_files(conn, params) do
    current_user = conn.assigns[:current_user]

    with token when not is_nil(token) <- AuthTokens.get_latest_token(current_user, :dropbox),
         {:ok, results} <- Dropbox.search_files(token, params) do
      json(conn, %{"status" => "success", "results" => results})
    end
  end

  @doc """
  Synchronizes Dropbox files with the database.
  """
  def sync_dropbox_files(conn, params) do
    current_user = conn.assigns[:current_user]

    with token when not is_nil(token) <- AuthTokens.get_latest_token(current_user, :dropbox),
         {:ok, result} <- Dropbox.sync_files_to_db(token, params) do
      json(conn, %{"status" => "success", "sync_result" => result})
    end
  end

  @doc """
  Downloads files from Dropbox based on provided file IDs.
  This endpoint accepts a list of file IDs and schedules downloads.
  """
  def download_dropbox_file(conn, %{"file_ids" => file_ids}) do
    user = conn.assigns[:current_user]
    org = conn.assigns[:current_org]

    with token when not is_nil(token) <- AuthTokens.get_latest_token(user, :dropbox) do
      results = Dropbox.schedule_download_to_minio(token, file_ids, user.id, org.id)

      conn
      |> put_status(:accepted)
      |> json(%{
        status: "processing",
        provider: "dropbox",
        results: results
      })
    end
  end

  @doc """
  Lists all folders in Dropbox.
  """
  def list_dropbox_folders(conn, params) do
    current_user = conn.assigns[:current_user]

    with token when not is_nil(token) <- AuthTokens.get_latest_token(current_user, :dropbox),
         {:ok, folders} <- Dropbox.list_all_folders(token, params) do
      json(conn, %{"status" => "success", "folders" => folders["folders"]})
    end
  end

  @doc """
  Searches for folders in Dropbox based on provided parameters.
  """
  def search_dropbox_folders(conn, params) do
    current_user = conn.assigns[:current_user]

    with token when not is_nil(token) <- AuthTokens.get_latest_token(current_user, :dropbox),
         {:ok, results} <- Dropbox.search_folders(token, params) do
      json(conn, %{"status" => "success", "folders" => results["folders"]})
    end
  end

  # @doc """
  # Lists all files within a specific Dropbox folder.
  # """
  # def list_dropbox_folder_files(conn, %{"folder_path" => folder_path} = params) do
  #   current_user = conn.assigns[:current_user]

  #   with token when not is_nil(token) <- AuthTokens.get_latest_token(current_user, :dropbox),
  #        {:ok, files} <- Dropbox.list_files_in_folder(token, folder_path, params) do
  #     json(conn, %{"status" => "success", "files" => files["files"]})
  #   end
  # end

  @doc """
  Retrieves metadata for a specific folder in Dropbox.
  """
  def get_dropbox_folder(conn, %{"folder_path" => folder_path}) do
    current_user = conn.assigns[:current_user]

    with token when not is_nil(token) <- AuthTokens.get_latest_token(current_user, :dropbox),
         {:ok, metadata} <- Dropbox.get_folder_metadata(token, folder_path) do
      json(conn, %{"status" => "success", "folder_metadata" => metadata})
    end
  end

  # OneDrive endpoints
  @doc """
  Lists all files in OneDrive.
  """
  def list_onedrive_files(conn, params) do
    current_user = conn.assigns[:current_user]

    with token when not is_nil(token) <- AuthTokens.get_latest_token(current_user, :onedrive),
         {:ok, files} <- Onedrive.list_all_files(token, params) do
      json(conn, %{"status" => "success", "files" => files["files"]})
    end
  end

  @doc """
  Retrieves metadata for a specific file in OneDrive.
  """
  def get_onedrive_file(conn, %{"file_id" => file_id}) do
    current_user = conn.assigns[:current_user]

    with token when not is_nil(token) <- AuthTokens.get_latest_token(current_user, :onedrive),
         {:ok, metadata} <- Onedrive.get_file_metadata(token, file_id) do
      json(conn, %{"status" => "success", "file_metadata" => metadata})
    end
  end

  @doc """
  Lists all PDF files in OneDrive.
  """
  def list_all_onedrive_pdfs(conn, params) do
    current_user = conn.assigns[:current_user]

    with token when not is_nil(token) <- AuthTokens.get_latest_token(current_user, :onedrive),
         {:ok, pdfs} <- Onedrive.list_all_pdfs(token, params) do
      json(conn, %{"status" => "success", "pdfs" => pdfs["files"]})
    end
  end

  @doc """
  Searches for files in OneDrive based on provided parameters.
  """
  def search_onedrive_files(conn, params) do
    current_user = conn.assigns[:current_user]

    with token when not is_nil(token) <- AuthTokens.get_latest_token(current_user, :onedrive),
         {:ok, results} <- Onedrive.search_files(token, params) do
      json(conn, %{"status" => "success", "results" => results})
    end
  end

  @doc """
  Synchronizes OneDrive files with the database.
  """
  def sync_onedrive_files(conn, params) do
    current_user = conn.assigns[:current_user]

    with token when not is_nil(token) <- AuthTokens.get_latest_token(current_user, :onedrive),
         {:ok, result} <- Onedrive.sync_files_to_db(token, params) do
      json(conn, %{"status" => "success", "sync_result" => result})
    end
  end

  @doc """
  Downloads files from OneDrive based on provided file IDs.
  This endpoint accepts a list of file IDs and schedules downloads.
  """
  def download_onedrive_file(conn, %{"file_ids" => file_ids}) do
    user = conn.assigns[:current_user]
    # need to be changed
    org = conn.assigns[:current_org]

    with token when not is_nil(token) <- AuthTokens.get_latest_token(user, :onedrive) do
      results = Onedrive.schedule_download_to_minio(token, file_ids, user.id, org.id)

      conn
      |> put_status(:accepted)
      |> json(%{
        status: "processing",
        provider: "onedrive",
        results: results
      })
    end
  end

  @doc """
  Lists all folders in OneDrive.
  """
  def list_onedrive_folders(conn, params) do
    current_user = conn.assigns[:current_user]

    with token when not is_nil(token) <- AuthTokens.get_latest_token(current_user, :onedrive),
         {:ok, folders} <- Onedrive.list_all_folders(token, params) do
      json(conn, %{"status" => "success", "folders" => folders["folders"]})
    end
  end

  @doc """
  Searches for folders in OneDrive based on provided parameters.
  """
  def search_onedrive_folders(conn, params) do
    current_user = conn.assigns[:current_user]

    with token when not is_nil(token) <- AuthTokens.get_latest_token(current_user, :onedrive),
         {:ok, results} <- Onedrive.search_folders(token, params) do
      json(conn, %{"status" => "success", "folders" => results["folders"]})
    end
  end

  @doc """
  Lists all files within a specific OneDrive folder.
  """
  def list_onedrive_folder_files(conn, %{"folder_id" => folder_id} = params) do
    current_user = conn.assigns[:current_user]

    with token when not is_nil(token) <- AuthTokens.get_latest_token(current_user, :onedrive),
         {:ok, files} <- Onedrive.list_files_in_folder(token, folder_id, params) do
      json(conn, %{"status" => "success", "files" => files["files"]})
    end
  end

  @doc """
  Retrieves metadata for a specific folder in OneDrive.
  """
  def get_onedrive_folder(conn, %{"folder_id" => folder_id}) do
    current_user = conn.assigns[:current_user]

    with token when not is_nil(token) <- AuthTokens.get_latest_token(current_user, :onedrive),
         {:ok, metadata} <- Onedrive.get_folder_metadata(token, folder_id) do
      json(conn, %{"status" => "success", "folder_metadata" => metadata})
    end
  end
end
