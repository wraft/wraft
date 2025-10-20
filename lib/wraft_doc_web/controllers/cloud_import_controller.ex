defmodule WraftDocWeb.Api.V1.CloudImportController do
  @moduledoc """
  Controller for handling cloud provider interactions with Google Drive, Dropbox, and OneDrive.
  Provides fully independent endpoint implementations for each provider.
  """
  use WraftDocWeb, :controller
  use PhoenixSwagger

  plug WraftDocWeb.Plug.AddActionLog
  plug WraftDocWeb.Plug.FeatureFlagCheck, feature: :repository

  alias WraftDoc.CloudImport.Providers.Dropbox
  alias WraftDoc.CloudImport.Providers.GoogleDrive, as: Google
  alias WraftDoc.CloudImport.Providers.Onedrive
  alias WraftDoc.Integrations
  alias WraftDoc.Storage.StorageItem
  alias WraftDoc.Storage.StorageItems

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
      ImportRequest:
        swagger_schema do
          title("Import Request")
          description("Request to import files from Google Drive")

          properties do
            file_ids(:array, "List of file IDs to import",
              items: %Schema{type: :string},
              example: ["file1", "file2"]
            )
          end
        end,
      ImportResponse:
        swagger_schema do
          title("Import Response")
          description("Response for file import request")

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
        end,
      DropboxFile:
        swagger_schema do
          title("Dropbox File")
          description("A file from Dropbox")

          properties do
            id(:string, "The ID of the file", required: true)
            name(:string, "Name of the file")
            tag_type(:string, "Type tag (always 'file' for files)")
            path_display(:string, "Display path of the file")
            path_lower(:string, "Lowercase path of the file")
            size(:integer, "Size of the file in bytes")
            client_modified(:string, "Last modified time by client", format: "date-time")
            server_modified(:string, "Last modified time on server", format: "date-time")
          end

          example(%{
            "id" => "id:3a2b1c0d9e8f7g",
            "name" => "example.pdf",
            "tag_type" => "file",
            "path_display" => "/Documents/example.pdf",
            "path_lower" => "/documents/example.pdf",
            "size" => 1024,
            "client_modified" => "2023-01-01T12:00:00Z",
            "server_modified" => "2023-01-01T12:00:00Z"
          })
        end,
      DropboxFileList:
        swagger_schema do
          title("Dropbox File List")
          description("List of files from Dropbox")

          properties do
            files(Schema.ref(:DropboxFile), "List of files", type: :array)
            has_more(:boolean, "Whether there are more files available")
            cursor(:string, "Cursor for pagination")
          end

          example(%{
            "files" => [
              %{
                "id" => "id:3a2b1c0d9e8f7g",
                "name" => "example.pdf"
              }
            ],
            "has_more" => true,
            "cursor" => "AAFqMWZ4Z2w5OG8yMTU5N2Q5NjYyNzkzODlmYTkyZjI4NzA"
          })
        end,
      DropboxFolder:
        swagger_schema do
          title("Dropbox Folder")
          description("A folder from Dropbox")

          properties do
            id(:string, "The ID of the folder", required: true)
            name(:string, "Name of the folder")
            tag_type(:string, "Type tag (always 'folder' for folders)")
            path_display(:string, "Display path of the folder")
            path_lower(:string, "Lowercase path of the folder")
          end

          example(%{
            "id" => "id:7g6f5e4d3c2b1a0",
            "name" => "Example Folder",
            "tag_type" => "folder",
            "path_display" => "/Documents/Example Folder",
            "path_lower" => "/documents/example folder"
          })
        end,
      DropboxFolderList:
        swagger_schema do
          title("Dropbox Folder List")
          description("List of folders from Dropbox")

          properties do
            folders(Schema.ref(:DropboxFolder), "List of folders", type: :array)
          end

          example(%{
            "folders" => [
              %{
                "id" => "id:7g6f5e4d3c2b1a0",
                "name" => "Example Folder"
              }
            ]
          })
        end,
      OneDriveFile:
        swagger_schema do
          title("OneDrive File")
          description("A file from OneDrive")

          properties do
            id(:string, "The ID of the file", required: true)
            name(:string, "Name of the file")
            size(:integer, "Size of the file in bytes")
            webUrl(:string, "URL to view the file in OneDrive")
            lastModifiedDateTime(:string, "Last modified time", format: "date-time")
            createdDateTime(:string, "Creation time", format: "date-time")
            file(:object, "File metadata from OneDrive")
          end

          example(%{
            "id" => "1234567890ABC",
            "name" => "example.pdf",
            "size" => 1024,
            "webUrl" => "https://onedrive.live.com/redir?resid=1234567890ABC",
            "lastModifiedDateTime" => "2023-01-01T12:00:00Z",
            "createdDateTime" => "2023-01-01T10:00:00Z",
            "file" => %{
              "mimeType" => "application/pdf"
            }
          })
        end,
      OneDriveFileList:
        swagger_schema do
          title("OneDrive File List")
          description("List of files from OneDrive")

          properties do
            files(Schema.ref(:OneDriveFile), "List of files", type: :array)
          end

          example(%{
            "files" => [
              %{
                "id" => "1234567890ABC",
                "name" => "example.pdf"
              }
            ]
          })
        end,
      OneDriveFolder:
        swagger_schema do
          title("OneDrive Folder")
          description("A folder from OneDrive")

          properties do
            id(:string, "The ID of the folder", required: true)
            name(:string, "Name of the folder")
            folder(:object, "Folder metadata")
            lastModifiedDateTime(:string, "Last modified time", format: "date-time")
            createdDateTime(:string, "Creation time", format: "date-time")
            parentReference(:object, "Parent folder reference")
          end

          example(%{
            "id" => "ABCDEF1234567890",
            "name" => "Example Folder",
            "folder" => %{
              "childCount" => 5
            },
            "lastModifiedDateTime" => "2023-01-01T12:00:00Z",
            "createdDateTime" => "2023-01-01T10:00:00Z",
            "parentReference" => %{
              "driveId" => "drive123",
              "id" => "parent456"
            }
          })
        end,
      OneDriveFolderList:
        swagger_schema do
          title("OneDrive Folder List")
          description("List of folders from OneDrive")

          properties do
            folders(Schema.ref(:OneDriveFolder), "List of folders", type: :array)
          end

          example(%{
            "folders" => [
              %{
                "id" => "ABCDEF1234567890",
                "name" => "Example Folder"
              }
            ]
          })
        end,
      DownloadRequest:
        swagger_schema do
          title("Download Request")
          description("Request to download files from cloud storage")

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
            provider(:string, "Provider name", enum: ["dropbox", "onedrive"])
            results(:array, "Download job details")
          end

          example(%{
            status: "processing",
            provider: "dropbox",
            results: [
              %{
                file_id: "id:3a2b1c0d9e8f7g",
                status: "scheduled"
              }
            ]
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
    response(400, "Bad Request")
    response(403, "Unauthorized")
  end

  @doc """
  Lists all files in Google Drive.
  pagination can be handled via passing `page_token` and `page_size` params.
  """
  def list_gdrive_files(conn, params) do
    current_user = conn.assigns[:current_user]

    with {:ok, token} <-
           Integrations.get_latest_token(current_user, "google_drive"),
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
    response(400, "Bad Request")
    response(403, "Unauthorized")
    response(404, "File not found")
  end

  @doc """
  Retrieves metadata for a specific file in Google Drive.
  This endpoint requires a `file_id` parameter to identify the file.
  """
  def get_gdrive_file(conn, %{"file_id" => file_id}) do
    current_user = conn.assigns[:current_user]

    with {:ok, token} <-
           Integrations.get_latest_token(current_user, "google_drive"),
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
    response(400, "Bad Request")
    response(403, "Unauthorized")
  end

  @doc """
  Lists all PDF files in Google Drive.
  pagination can be handled via passing `page_token` and `page_size` params.
  """
  def list_all_gdrive_pdfs(conn, params) do
    current_user = conn.assigns[:current_user]

    with {:ok, token} <-
           Integrations.get_latest_token(current_user, "google_drive"),
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
    response(400, "Bad Request")
    response(403, "Unauthorized")
  end

  @doc """
  Searches for files in Google Drive based on provided parameters.
  """
  def search_gdrive_files(conn, params) do
    current_user = conn.assigns[:current_user]

    with {:ok, token} <-
           Integrations.get_latest_token(current_user, "google_drive"),
         {:ok, results} <- Google.search_files(token, params) do
      json(conn, %{"status" => "success", "results" => results})
    end
  end

  @doc """
  Synchronizes Google Drive files with the database.
  This endpoint fetches files from Google Drive and updates the database.
  """
  swagger_path :sync_gdrive_files do
    post("/clouds/google/sync_files")
    summary("Sync Google Drive files with database")
    description("Fetches files from Google Drive and updates the database")

    response(200, "OK", Schema.ref(:SyncResponse))
    response(400, "Bad Request")
    response(403, "Unauthorized")
  end

  def sync_gdrive_files(conn, params) do
    current_user = conn.assigns[:current_user]

    with {:ok, token} <-
           Integrations.get_latest_token(current_user, "google_drive"),
         {:ok, result} <- Google.sync_files_to_db(token, params, current_user) do
      json(conn, %{"status" => "success", "sync_result" => result})
    end
  end

  swagger_path :import_gdrive_file do
    post("/clouds/google/import")
    summary("Download files from Google Drive")
    description("Schedules import of specified files from Google Drive to MinIO")

    parameters do
      file_ids(:body, Schema.ref(:ImportRequest), "List of file IDs to import", required: true)
      folder_id(:body, :string, "Folder id of repository", required: true)
    end

    response(202, "Accepted", Schema.ref(:ImportResponse))
    response(400, "Bad Request")
    response(403, "Unauthorized")
  end

  @doc """
  Downloads files from Google Drive based on provided file IDs.
  This endpoint accepts a list of file IDs and schedules downloads.
  params requied ,`file_ids` should be a list of file IDs to download
  """
  def import_gdrive_file(conn, %{"folder_id" => folder_id} = params) do
    current_user = conn.assigns[:current_user]

    with {:ok, token} <- Integrations.get_latest_token(current_user, "google_drive"),
         %StorageItem{} = folder_item <-
           StorageItems.get_folder(folder_id, current_user.current_org_id),
         {:ok, storage_items} <-
           Google.sync_import_files_to_db(token, params, current_user, folder_item) do
      Google.schedule_download_to_minio(
        current_user,
        storage_items,
        folder_item
      )

      conn
      |> put_status(:accepted)
      |> put_view(WraftDocWeb.Api.V1.StorageItemView)
      |> render("cloud_index.json", %{
        status: "processing",
        provider: "google_drive",
        storage_items: storage_items
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
    response(400, "Bad Request")
    response(403, "Unauthorized")
  end

  @doc """
  Retrieves all folders in the user's Google Drive.
  pagination can be handled via passing `page_token` and `page_size` params.
  """

  def list_gdrive_folders(conn, params) do
    current_user = conn.assigns[:current_user]

    with {:ok, token} <-
           Integrations.get_latest_token(current_user, "google_drive"),
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
    response(400, "Bad Request")
    response(403, "Unauthorized")
  end

  @doc """
  Searches for folders in Google Drive based on provided parameters.
  This endpoint allows users to search for folders in their Google Drive.
  """
  def search_gdrive_folders(conn, params) do
    current_user = conn.assigns[:current_user]

    with {:ok, token} <-
           Integrations.get_latest_token(current_user, "google_drive"),
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
    response(403, "Unauthorized")
    response(404, "Folder not found")
  end

  @doc """
  Lists all files within a specific Google Drive folder.
  """
  def list_gdrive_folder_files(conn, %{"folder_id" => folder_id} = params) do
    current_user = conn.assigns[:current_user]

    with {:ok, token} <-
           Integrations.get_latest_token(current_user, "google_drive"),
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
    response(403, "Unauthorized")
    response(404, "Folder not found")
  end

  @doc """
  Retrieves metadata for a specific folder in Google Drive.
  """
  def get_gdrive_folder(conn, %{"folder_id" => folder_id}) do
    current_user = conn.assigns[:current_user]

    with {:ok, token} <-
           Integrations.get_latest_token(current_user, "google_drive"),
         {:ok, metadata} <- Google.get_folder_metadata(token, folder_id) do
      json(conn, %{"status" => "success", "folder_metadata" => metadata})
    end
  end

  swagger_path :list_dropbox_files do
    get("/clouds/dropbox/files")
    summary("List Dropbox files")
    description("Lists all files in the user's Dropbox account")

    parameters do
      path(:query, :string, "Path to list files from (default: \"\")", required: false)
      recursive(:query, :boolean, "Whether to list files recursively", required: false)
      limit(:query, :integer, "Maximum number of files to return", required: false)
    end

    response(200, "Success", Schema.ref(:DropboxFileList))
    response(400, "Bad Request")
    response(403, "Unauthorized")
  end

  @doc """
  Lists all files in Dropbox.
  """
  def list_dropbox_files(conn, params) do
    current_user = conn.assigns[:current_user]

    with {:ok, token} <- Integrations.get_latest_token(current_user, :dropbox),
         {:ok, files} <- Dropbox.list_all_files(token, params) do
      json(conn, %{"status" => "success", "files" => files["files"]})
    end
  end

  swagger_path :get_dropbox_file do
    get("/clouds/dropbox/file/{file_id}")
    summary("Get Dropbox file metadata")
    description("Retrieves metadata for a specific file in Dropbox")

    parameters do
      file_id(:path, :string, "The ID or path of the file in Dropbox", required: true)
    end

    response(200, "Success", %{
      properties: %{
        status: %{type: :string, description: "Status of the request", example: "success"},
        file_metadata: Schema.ref(:DropboxFile)
      }
    })

    response(400, "Bad Request")
    response(403, "Unauthorized")
    response(404, "File Not Found")
  end

  @doc """
  Retrieves metadata for a specific file in Dropbox.
  """
  def get_dropbox_file(conn, %{"file_id" => file_id}) do
    current_user = conn.assigns[:current_user]

    with {:ok, token} <- Integrations.get_latest_token(current_user, :dropbox),
         {:ok, metadata} <- Dropbox.get_file_metadata(token, file_id) do
      json(conn, %{"status" => "success", "file_metadata" => metadata})
    end
  end

  swagger_path :list_all_dropbox_pdfs do
    get("/clouds/dropbox/pdfs")
    summary("List all PDF files in Dropbox")
    description("Lists all PDF files in the user's Dropbox account")

    parameters do
      path(:query, :string, "Path to search for PDFs (default: \"\")", required: false)
      limit(:query, :integer, "Maximum number of PDFs to return", required: false)
      recursive(:query, :boolean, "Whether to search recursively", required: false)
    end

    response(200, "Success", Schema.ref(:DropboxFileList))
    response(400, "Bad Request")
    response(403, "Unauthorized")
    response(404, "File Not Found")
  end

  @doc """
  Lists all PDF files in Dropbox.
  """
  def list_all_dropbox_pdfs(conn, params) do
    current_user = conn.assigns[:current_user]

    with {:ok, token} <- Integrations.get_latest_token(current_user, :dropbox),
         {:ok, pdfs} <- Dropbox.list_all_pdfs(token, params) do
      json(conn, %{"status" => "success", "pdfs" => pdfs["files"]})
    end
  end

  swagger_path :search_dropbox_files do
    get("/clouds/dropbox/search")
    summary("Search Dropbox files")
    description("Searches for files in Dropbox based on provided parameters")

    parameters do
      query(:query, :string, "Search query string", required: true)

      content_type(:query, :string, "Filter by content type (e.g., \"application/pdf\")",
        required: false
      )

      limit(:query, :integer, "Maximum number of results to return (default: 100)",
        required: false
      )
    end

    response(200, "Success", Schema.ref(:DropboxFileList))
    response(400, "Bad Request")
    response(403, "Unauthorized")
  end

  @doc """
  Searches for files in Dropbox based on provided parameters.
  """
  def search_dropbox_files(conn, params) do
    current_user = conn.assigns[:current_user]

    with {:ok, token} <- Integrations.get_latest_token(current_user, :dropbox),
         {:ok, results} <- Dropbox.search_files(token, params) do
      json(conn, %{"status" => "success", "results" => results})
    end
  end

  swagger_path :sync_dropbox_files do
    post("/clouds/dropbox/sync_files")
    summary("Sync Dropbox files with database")
    description("Synchronizes files from Dropbox with the application database")

    parameters do
      path(:query, :string, "Path to synchronize files from", required: false)
      recursive(:query, :boolean, "Whether to synchronize files recursively", required: false)
    end

    response(200, "Success", Schema.ref(:SyncResponse))
    response(400, "Bad Request")
    response(403, "Unauthorized")
  end

  @doc """
  Synchronizes Dropbox files with the database.
  """
  def sync_dropbox_files(conn, params) do
    current_user = conn.assigns[:current_user]

    with {:ok, token} <- Integrations.get_latest_token(current_user, :dropbox),
         {:ok, result} <- Dropbox.sync_files_to_db(token, params, current_user) do
      json(conn, %{"status" => "success", "sync_result" => result})
    end
  end

  swagger_path :download_dropbox_file do
    post("/clouds/dropbox/download")
    summary("Download files from Dropbox")

    description(
      "Downloads files from Dropbox based on provided file IDs and schedules the downloads"
    )

    parameters do
      body(:body, Schema.ref(:DownloadRequest), "File IDs to download", required: true)
    end

    response(202, "Accepted", Schema.ref(:DownloadResponse))
    response(400, "Bad Request")
    response(403, "Unauthorized")
  end

  @doc """
  Downloads files from Dropbox based on provided file IDs.
  This endpoint accepts a list of file IDs and schedules downloads.
  """
  def download_dropbox_file(conn, %{"file_ids" => file_ids, "folder_id" => folder_id}) do
    current_user = conn.assigns[:current_user]

    with {:ok, _token} <- Integrations.get_latest_token(current_user, :dropbox),
         %StorageItem{} = storage_item <-
           StorageItems.get_folder(folder_id, current_user.current_org_id) do
      results = Dropbox.schedule_download_to_minio(current_user, file_ids, storage_item)

      conn
      |> put_status(:accepted)
      |> json(%{
        status: "processing",
        provider: "dropbox",
        results: results
      })
    end
  end

  swagger_path :list_dropbox_folders do
    get("/clouds/dropbox/folders")
    summary("List Dropbox folders")
    description("Lists all folders in the user's Dropbox account")

    parameters do
      path(:query, :string, "Path to list folders from (default: \"\")", required: false)
      recursive(:query, :boolean, "Whether to list folders recursively", required: false)
    end

    response(200, "Success", Schema.ref(:DropboxFolderList))
    response(400, "Bad Request")
    response(403, "Unauthorized")
  end

  @doc """
  Lists all folders in Dropbox.
  """
  def list_dropbox_folders(conn, params) do
    current_user = conn.assigns[:current_user]

    with {:ok, token} <- Integrations.get_latest_token(current_user, :dropbox),
         {:ok, folders} <- Dropbox.list_all_folders(token, params) do
      json(conn, %{"status" => "success", "folders" => folders["folders"]})
    end
  end

  swagger_path :search_dropbox_folders do
    get("/clouds/dropbox/folders/search")
    summary("Search Dropbox folders")
    description("Searches for folders in Dropbox based on provided parameters")

    parameters do
      query(:query, :string, "Search query string", required: true)

      max_results(:query, :integer, "Maximum number of results to return (default: 100)",
        required: false
      )
    end

    response(200, "Success", Schema.ref(:DropboxFolderList))
    response(400, "Bad Request")
    response(403, "Unauthorized")
  end

  @doc """
  Searches for folders in Dropbox based on provided parameters.
  """
  def search_dropbox_folders(conn, params) do
    current_user = conn.assigns[:current_user]

    with {:ok, token} <- Integrations.get_latest_token(current_user, :dropbox),
         {:ok, results} <- Dropbox.search_folders(token, params) do
      json(conn, %{"status" => "success", "folders" => results["folders"]})
    end
  end

  # @doc """
  # Lists all files within a specific Dropbox folder.
  # """
  # def list_dropbox_folder_files(conn, %{"folder_path" => folder_path} = params) do
  #   current_user = conn.assigns[:current_user]

  #   with {:ok, token}  <- AuthTokens.get_latest_token(current_user, :dropbox),
  #        {:ok, files} <- Dropbox.list_files_in_folder(token, folder_path, params) do
  #     json(conn, %{"status" => "success", "files" => files["files"]})
  #   end
  # end

  swagger_path :get_dropbox_folder do
    get("/clouds/dropbox/folder/{folder_path}")
    summary("Get Dropbox folder metadata")
    description("Retrieves metadata for a specific folder in Dropbox")

    parameters do
      folder_path(:path, :string, "Path of the folder in Dropbox", required: true)
    end

    response(200, "Success", %{
      properties: %{
        status: %{type: :string, description: "Status of the request", example: "success"},
        folder_metadata: Schema.ref(:DropboxFolder)
      }
    })

    response(400, "Bad Request")
    response(403, "Unauthorized")
    response(404, "Folder Not Found")
  end

  @doc """
  Retrieves metadata for a specific folder in Dropbox.
  """
  def get_dropbox_folder(conn, %{"folder_path" => folder_path}) do
    current_user = conn.assigns[:current_user]

    with {:ok, token} <- Integrations.get_latest_token(current_user, :dropbox),
         {:ok, metadata} <- Dropbox.get_folder_metadata(token, folder_path) do
      json(conn, %{"status" => "success", "folder_metadata" => metadata})
    end
  end

  swagger_path :list_onedrive_files do
    get("/clouds/onedrive/files")
    summary("List OneDrive files")
    description("Lists all files in the user's OneDrive account")

    parameters do
      path(:query, :string, "Path to list files from (default: \"/drive/root/children\")",
        required: false
      )

      query(:query, :string, "Filter query", required: false)
    end

    response(200, "Success", Schema.ref(:OneDriveFileList))
    response(400, "Bad Request")
    response(403, "Unauthorized")
  end

  @doc """
  Lists all files in OneDrive.
  """
  def list_onedrive_files(conn, params) do
    current_user = conn.assigns[:current_user]

    with {:ok, token} <- Integrations.get_latest_token(current_user, :onedrive),
         {:ok, files} <- Onedrive.list_all_files(token, params) do
      json(conn, %{"status" => "success", "files" => files["files"]})
    end
  end

  swagger_path :get_onedrive_file do
    get("/clouds/onedrive/file/{file_id}")
    summary("Get OneDrive file metadata")
    description("Retrieves metadata for a specific file in OneDrive")

    parameters do
      file_id(:path, :string, "The ID of the file in OneDrive", required: true)
    end

    response(200, "Success", %{
      properties: %{
        status: %{type: :string, description: "Status of the request", example: "success"},
        file_metadata: Schema.ref(:OneDriveFile)
      }
    })

    response(400, "Bad Request")
    response(403, "Unauthorized")
    response(404, "File Not Found")
  end

  @doc """
  Retrieves metadata for a specific file in OneDrive.
  """
  def get_onedrive_file(conn, %{"file_id" => file_id}) do
    current_user = conn.assigns[:current_user]

    with {:ok, token} <- Integrations.get_latest_token(current_user, :onedrive),
         {:ok, metadata} <- Onedrive.get_file_metadata(token, file_id) do
      json(conn, %{"status" => "success", "file_metadata" => metadata})
    end
  end

  swagger_path :list_all_onedrive_pdfs do
    get("/clouds/onedrive/pdfs")
    summary("List all PDF files in OneDrive")
    description("Lists all PDF files in the user's OneDrive account")

    parameters do
      top(:query, :integer, "Maximum number of results to return (default: 1000)",
        required: false
      )
    end

    response(200, "Success", Schema.ref(:OneDriveFileList))
    response(400, "Bad Request")
    response(403, "Unauthorized")
  end

  @doc """
  Lists all PDF files in OneDrive.
  """
  def list_all_onedrive_pdfs(conn, params) do
    current_user = conn.assigns[:current_user]

    with {:ok, token} <- Integrations.get_latest_token(current_user, :onedrive),
         {:ok, pdfs} <- Onedrive.list_all_pdfs(token, params) do
      json(conn, %{"status" => "success", "pdfs" => pdfs["files"]})
    end
  end

  swagger_path :search_onedrive_files do
    get("/clouds/onedrive/search")
    summary("Search OneDrive files")
    description("Searches for files in OneDrive based on provided parameters")

    parameters do
      query(:query, :string, "Search query string", required: true)

      content_type(:query, :string, "Filter by content type (e.g., \"application/pdf\")",
        required: false
      )

      limit(:query, :integer, "Maximum number of results to return (default: 100)",
        required: false
      )
    end

    response(200, "Success", Schema.ref(:OneDriveFileList))
    response(400, "Bad Request")
    response(403, "Unauthorized")
  end

  @doc """
  Searches for files in OneDrive based on provided parameters.
  """
  def search_onedrive_files(conn, params) do
    current_user = conn.assigns[:current_user]

    with {:ok, token} <- Integrations.get_latest_token(current_user, :onedrive),
         {:ok, results} <- Onedrive.search_files(token, params) do
      json(conn, %{"status" => "success", "results" => results})
    end
  end

  swagger_path :sync_onedrive_files do
    post("/clouds/onedrive/sync_files")
    summary("Sync OneDrive files with database")
    description("Synchronizes files from OneDrive with the application database")

    parameters do
      path(:query, :string, "Path to synchronize files from", required: false)
      recursive(:query, :boolean, "Whether to synchronize files recursively", required: false)
    end

    response(200, "Success", Schema.ref(:SyncResponse))
    response(400, "Bad Request")
    response(403, "Unauthorized")
  end

  @doc """
  Synchronizes OneDrive files with the database.
  """
  def sync_onedrive_files(conn, params) do
    current_user = conn.assigns[:current_user]

    with {:ok, token} <- Integrations.get_latest_token(current_user, :onedrive),
         {:ok, result} <- Onedrive.sync_files_to_db(token, params, current_user) do
      json(conn, %{"status" => "success", "sync_result" => result})
    end
  end

  swagger_path :download_onedrive_file do
    post("/clouds/onedrive/download")
    summary("Download files from OneDrive")

    description(
      "Downloads files from OneDrive based on provided file IDs and schedules the downloads"
    )

    parameters do
      body(:body, Schema.ref(:DownloadRequest), "File IDs to download", required: true)
    end

    response(202, "Accepted", Schema.ref(:DownloadResponse))
    response(400, "Bad Request")
    response(403, "Unauthorized")
  end

  @doc """
  Downloads files from OneDrive based on provided file IDs.
  This endpoint accepts a list of file IDs and schedules downloads.
  """
  def download_onedrive_file(conn, %{"file_ids" => file_ids, "folder_id" => folder_id}) do
    current_user = conn.assigns[:current_user]

    with {:ok, _token} <- Integrations.get_latest_token(current_user, :onedrive),
         %StorageItem{} = storage_item <-
           StorageItems.get_folder(folder_id, current_user.current_org_id) do
      results = Onedrive.schedule_download_to_minio(current_user, file_ids, storage_item)

      conn
      |> put_status(:accepted)
      |> json(%{
        status: "processing",
        provider: "onedrive",
        results: results
      })
    end
  end

  swagger_path :list_onedrive_folders do
    get("/clouds/onedrive/folders")
    summary("List OneDrive folders")
    description("Lists all folders in the user's OneDrive account")

    parameters do
      path(:query, :string, "Path to list folders from (default: \"/drive/root/children\")",
        required: false
      )
    end

    response(200, "Success", Schema.ref(:OneDriveFolderList))
    response(400, "Bad Request")
    response(403, "Unauthorized")
  end

  @doc """
  Lists all folders in OneDrive.
  """
  def list_onedrive_folders(conn, params) do
    current_user = conn.assigns[:current_user]

    with {:ok, token} <- Integrations.get_latest_token(current_user, :onedrive),
         {:ok, folders} <- Onedrive.list_all_folders(token, params) do
      json(conn, %{"status" => "success", "folders" => folders["folders"]})
    end
  end

  swagger_path :search_onedrive_folders do
    get("/clouds/onedrive/folders/search")
    summary("Search OneDrive folders")
    description("Searches for folders in OneDrive based on provided parameters")

    parameters do
      query(:query, :string, "Search query string", required: true)
      top(:query, :integer, "Maximum number of results to return (default: 100)", required: false)
    end

    response(200, "Success", Schema.ref(:OneDriveFolderList))
    response(400, "Bad Request")
    response(403, "Unauthorized")
  end

  @doc """
  Searches for folders in OneDrive based on provided parameters.
  """
  def search_onedrive_folders(conn, params) do
    current_user = conn.assigns[:current_user]

    with {:ok, token} <- Integrations.get_latest_token(current_user, :onedrive),
         {:ok, results} <- Onedrive.search_folders(token, params) do
      json(conn, %{"status" => "success", "folders" => results["folders"]})
    end
  end

  swagger_path :list_onedrive_folder_files do
    get("/clouds/onedrive/folder/{folder_id}/files")
    summary("List files in OneDrive folder")
    description("Lists all files within a specific folder in OneDrive")

    parameters do
      folder_id(:path, :string, "The ID of the folder in OneDrive", required: true)

      top(:query, :integer, "Maximum number of results to return (default: 1000)",
        required: false
      )

      file_type(:query, :string, "Filter by file type (pdf, image, document, all)",
        required: false
      )
    end

    response(200, "Success", Schema.ref(:OneDriveFileList))
    response(400, "Bad Request")
    response(403, "Unauthorized")
    response(404, "Folder Not Found")
  end

  @doc """
  Lists all files within a specific OneDrive folder.
  """
  def list_onedrive_folder_files(conn, %{"folder_id" => folder_id} = params) do
    current_user = conn.assigns[:current_user]

    with {:ok, token} <- Integrations.get_latest_token(current_user, :onedrive),
         {:ok, files} <- Onedrive.list_files_in_folder(token, folder_id, params) do
      json(conn, %{"status" => "success", "files" => files["files"]})
    end
  end

  swagger_path :get_onedrive_folder do
    get("/clouds/onedrive/folder/{folder_id}")
    summary("Get OneDrive folder metadata")
    description("Retrieves metadata for a specific folder in OneDrive")

    parameters do
      folder_id(:path, :string, "The ID of the folder in OneDrive", required: true)
    end

    response(200, "Success", %{
      properties: %{
        status: %{type: :string, description: "Status of the request", example: "success"},
        folder_metadata: Schema.ref(:OneDriveFolder)
      }
    })

    response(400, "Bad Request")
    response(403, "Unauthorized")
    response(404, "Folder Not Found")
  end

  @doc """
  Retrieves metadata for a specific folder in OneDrive.
  """
  def get_onedrive_folder(conn, %{"folder_id" => folder_id}) do
    current_user = conn.assigns[:current_user]

    with {:ok, token} <- Integrations.get_latest_token(current_user, :onedrive),
         {:ok, metadata} <- Onedrive.get_folder_metadata(token, folder_id) do
      json(conn, %{"status" => "success", "folder_metadata" => metadata})
    end
  end
end
