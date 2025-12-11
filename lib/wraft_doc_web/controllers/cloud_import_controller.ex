defmodule WraftDocWeb.Api.V1.CloudImportController do
  @moduledoc """
  Controller for handling cloud provider interactions with Google Drive, Dropbox, and OneDrive.
  Provides fully independent endpoint implementations for each provider.
  """
  use WraftDocWeb, :controller
  use OpenApiSpex.ControllerSpecs

  plug WraftDocWeb.Plug.AddActionLog
  plug WraftDocWeb.Plug.FeatureFlagCheck, feature: :repository

  alias WraftDoc.CloudImport.Providers.Dropbox
  alias WraftDoc.CloudImport.Providers.GoogleDrive, as: Google
  alias WraftDoc.CloudImport.Providers.Onedrive
  alias WraftDoc.Integrations
  alias WraftDoc.Storages.StorageItem
  alias WraftDoc.Storages.StorageItems
  alias WraftDocWeb.Schemas.CloudImport, as: CloudImportSchema

  action_fallback(WraftDocWeb.FallbackController)

  require Logger

  tags(["CloudImport"])

  # Google Drive Operations

  operation(:list_gdrive_files,
    summary: "List Google Drive files",
    description: "Lists all files in Google Drive with optional pagination",
    parameters: [
      page_token: [in: :query, type: :string, description: "Token for pagination"],
      page_size: [in: :query, type: :integer, description: "Number of items per page"]
    ],
    responses: [
      ok: {"OK", "application/json", %OpenApiSpex.Schema{type: :object}},
      bad_request: {"Bad Request", "application/json", %OpenApiSpex.Schema{type: :object}},
      forbidden: {"Unauthorized", "application/json", %OpenApiSpex.Schema{type: :object}}
    ]
  )

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

  operation(:get_gdrive_file,
    summary: "Get Google Drive file metadata",
    description: "Retrieves metadata for a specific file in Google Drive",
    parameters: [
      file_id: [
        in: :path,
        type: :string,
        description: "ID of the file to retrieve",
        required: true
      ]
    ],
    responses: [
      ok: {"OK", "application/json", %OpenApiSpex.Schema{type: :object}},
      bad_request: {"Bad Request", "application/json", %OpenApiSpex.Schema{type: :object}},
      forbidden: {"Unauthorized", "application/json", %OpenApiSpex.Schema{type: :object}},
      not_found: {"File not found", "application/json", %OpenApiSpex.Schema{type: :object}}
    ]
  )

  def get_gdrive_file(conn, %{"file_id" => file_id}) do
    current_user = conn.assigns[:current_user]

    with {:ok, token} <-
           Integrations.get_latest_token(current_user, "google_drive"),
         {:ok, metadata} <- Google.get_file_metadata(token, file_id) do
      json(conn, %{"status" => "success", "file_metadata" => metadata})
    end
  end

  operation(:list_all_gdrive_pdfs,
    summary: "List all PDF files in Google Drive",
    description: "Lists all PDF files in Google Drive with optional pagination",
    parameters: [
      page_token: [in: :query, type: :string, description: "Token for pagination"],
      page_size: [in: :query, type: :integer, description: "Number of items per page"]
    ],
    responses: [
      ok: {"OK", "application/json", %OpenApiSpex.Schema{type: :object}},
      bad_request: {"Bad Request", "application/json", %OpenApiSpex.Schema{type: :object}},
      forbidden: {"Unauthorized", "application/json", %OpenApiSpex.Schema{type: :object}}
    ]
  )

  def list_all_gdrive_pdfs(conn, params) do
    current_user = conn.assigns[:current_user]

    with {:ok, token} <-
           Integrations.get_latest_token(current_user, "google_drive"),
         {:ok, pdfs} <- Google.list_all_pdfs(token, params) do
      json(conn, %{"status" => "success", "pdfs" => pdfs["files"]})
    end
  end

  operation(:search_gdrive_files,
    summary: "Search Google Drive files",
    description: "Searches for files in Google Drive based on query parameters",
    parameters: [
      query: [in: :query, type: :string, description: "Search query"],
      page_token: [in: :query, type: :string, description: "Token for pagination"],
      page_size: [in: :query, type: :integer, description: "Number of items per page"]
    ],
    responses: [
      ok: {"OK", "application/json", %OpenApiSpex.Schema{type: :object}},
      bad_request: {"Bad Request", "application/json", %OpenApiSpex.Schema{type: :object}},
      forbidden: {"Unauthorized", "application/json", %OpenApiSpex.Schema{type: :object}}
    ]
  )

  def search_gdrive_files(conn, params) do
    current_user = conn.assigns[:current_user]

    with {:ok, token} <-
           Integrations.get_latest_token(current_user, "google_drive"),
         {:ok, results} <- Google.search_files(token, params) do
      json(conn, %{"status" => "success", "results" => results})
    end
  end

  operation(:sync_gdrive_files,
    summary: "Sync Google Drive files with database",
    description: "Fetches files from Google Drive and updates the database",
    responses: [
      ok: {"OK", "application/json", %OpenApiSpex.Schema{type: :object}},
      bad_request: {"Bad Request", "application/json", %OpenApiSpex.Schema{type: :object}},
      forbidden: {"Unauthorized", "application/json", %OpenApiSpex.Schema{type: :object}}
    ]
  )

  def sync_gdrive_files(conn, params) do
    current_user = conn.assigns[:current_user]

    with {:ok, token} <-
           Integrations.get_latest_token(current_user, "google_drive"),
         {:ok, result} <- Google.sync_files_to_db(token, params, current_user) do
      json(conn, %{"status" => "success", "sync_result" => result})
    end
  end

  operation(:import_gdrive_file,
    summary: "Download files from Google Drive",
    description: "Schedules import of specified files from Google Drive to MinIO",
    request_body: {"Import request", "application/json", CloudImportSchema.ImportRequest},
    responses: [
      accepted: {"Accepted", "application/json", %OpenApiSpex.Schema{type: :object}},
      bad_request: {"Bad Request", "application/json", %OpenApiSpex.Schema{type: :object}},
      forbidden: {"Unauthorized", "application/json", %OpenApiSpex.Schema{type: :object}}
    ]
  )

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

  operation(:list_gdrive_folders,
    summary: "List Google Drive folders",
    description: "Lists all folders in Google Drive with optional pagination",
    parameters: [
      page_token: [in: :query, type: :string, description: "Token for pagination"],
      page_size: [in: :query, type: :integer, description: "Number of items per page"]
    ],
    responses: [
      ok: {"OK", "application/json", %OpenApiSpex.Schema{type: :object}},
      bad_request: {"Bad Request", "application/json", %OpenApiSpex.Schema{type: :object}},
      forbidden: {"Unauthorized", "application/json", %OpenApiSpex.Schema{type: :object}}
    ]
  )

  def list_gdrive_folders(conn, params) do
    current_user = conn.assigns[:current_user]

    with {:ok, token} <-
           Integrations.get_latest_token(current_user, "google_drive"),
         {:ok, folders} <- Google.list_all_folders(token, params) do
      json(conn, %{"status" => "success", "folders" => folders["files"]})
    end
  end

  operation(:search_gdrive_folders,
    summary: "Search Google Drive folders",
    description: "Searches for folders in Google Drive based on query parameters",
    parameters: [
      query: [in: :query, type: :string, description: "Search query"],
      page_token: [in: :query, type: :string, description: "Token for pagination"],
      page_size: [in: :query, type: :integer, description: "Number of items per page"]
    ],
    responses: [
      ok: {"OK", "application/json", %OpenApiSpex.Schema{type: :object}},
      bad_request: {"Bad Request", "application/json", %OpenApiSpex.Schema{type: :object}},
      forbidden: {"Unauthorized", "application/json", %OpenApiSpex.Schema{type: :object}}
    ]
  )

  def search_gdrive_folders(conn, params) do
    current_user = conn.assigns[:current_user]

    with {:ok, token} <-
           Integrations.get_latest_token(current_user, "google_drive"),
         {:ok, results} <- Google.search_folders(token, params) do
      json(conn, %{"status" => "success", "folders" => results["files"]})
    end
  end

  operation(:list_gdrive_folder_files,
    summary: "List files in Google Drive folder",
    description: "Lists all files within a specific Google Drive folder",
    parameters: [
      folder_id: [in: :path, type: :string, description: "ID of the folder", required: true],
      page_token: [in: :query, type: :string, description: "Token for pagination"],
      page_size: [in: :query, type: :integer, description: "Number of items per page"]
    ],
    responses: [
      ok: {"OK", "application/json", %OpenApiSpex.Schema{type: :object}},
      forbidden: {"Unauthorized", "application/json", %OpenApiSpex.Schema{type: :object}},
      not_found: {"Folder not found", "application/json", %OpenApiSpex.Schema{type: :object}}
    ]
  )

  def list_gdrive_folder_files(conn, %{"folder_id" => folder_id} = params) do
    current_user = conn.assigns[:current_user]

    with {:ok, token} <-
           Integrations.get_latest_token(current_user, "google_drive"),
         {:ok, files} <- Google.list_files_in_folder(token, folder_id, params) do
      json(conn, %{"status" => "success", "files" => files["files"]})
    end
  end

  operation(:get_gdrive_folder,
    summary: "Get Google Drive folder metadata",
    description: "Retrieves metadata for a specific folder in Google Drive",
    parameters: [
      folder_id: [in: :path, type: :string, description: "ID of the folder", required: true]
    ],
    responses: [
      ok: {"OK", "application/json", %OpenApiSpex.Schema{type: :object}},
      forbidden: {"Unauthorized", "application/json", %OpenApiSpex.Schema{type: :object}},
      not_found: {"Folder not found", "application/json", %OpenApiSpex.Schema{type: :object}}
    ]
  )

  def get_gdrive_folder(conn, %{"folder_id" => folder_id}) do
    current_user = conn.assigns[:current_user]

    with {:ok, token} <-
           Integrations.get_latest_token(current_user, "google_drive"),
         {:ok, metadata} <- Google.get_folder_metadata(token, folder_id) do
      json(conn, %{"status" => "success", "folder_metadata" => metadata})
    end
  end

  # Dropbox Operations

  operation(:list_dropbox_files,
    summary: "List Dropbox files",
    description: "Lists all files in the user's Dropbox account",
    parameters: [
      path: [in: :query, type: :string, description: "Path to list files from (default: \"\")"],
      recursive: [in: :query, type: :boolean, description: "Whether to list files recursively"],
      limit: [in: :query, type: :integer, description: "Maximum number of files to return"]
    ],
    responses: [
      ok: {"Success", "application/json", %OpenApiSpex.Schema{type: :object}},
      bad_request: {"Bad Request", "application/json", %OpenApiSpex.Schema{type: :object}},
      forbidden: {"Unauthorized", "application/json", %OpenApiSpex.Schema{type: :object}}
    ]
  )

  def list_dropbox_files(conn, params) do
    current_user = conn.assigns[:current_user]

    with {:ok, token} <- Integrations.get_latest_token(current_user, :dropbox),
         {:ok, files} <- Dropbox.list_all_files(token, params) do
      json(conn, %{"status" => "success", "files" => files["files"]})
    end
  end

  operation(:get_dropbox_file,
    summary: "Get Dropbox file metadata",
    description: "Retrieves metadata for a specific file in Dropbox",
    parameters: [
      file_id: [
        in: :path,
        type: :string,
        description: "The ID or path of the file in Dropbox",
        required: true
      ]
    ],
    responses: [
      ok: {"Success", "application/json", %OpenApiSpex.Schema{type: :object}},
      bad_request: {"Bad Request", "application/json", %OpenApiSpex.Schema{type: :object}},
      forbidden: {"Unauthorized", "application/json", %OpenApiSpex.Schema{type: :object}},
      not_found: {"File Not Found", "application/json", %OpenApiSpex.Schema{type: :object}}
    ]
  )

  def get_dropbox_file(conn, %{"file_id" => file_id}) do
    current_user = conn.assigns[:current_user]

    with {:ok, token} <- Integrations.get_latest_token(current_user, :dropbox),
         {:ok, metadata} <- Dropbox.get_file_metadata(token, file_id) do
      json(conn, %{"status" => "success", "file_metadata" => metadata})
    end
  end

  operation(:list_all_dropbox_pdfs,
    summary: "List all PDF files in Dropbox",
    description: "Lists all PDF files in the user's Dropbox account",
    parameters: [
      path: [in: :query, type: :string, description: "Path to search for PDFs (default: \"\")"],
      limit: [in: :query, type: :integer, description: "Maximum number of PDFs to return"],
      recursive: [in: :query, type: :boolean, description: "Whether to search recursively"]
    ],
    responses: [
      ok: {"Success", "application/json", %OpenApiSpex.Schema{type: :object}},
      bad_request: {"Bad Request", "application/json", %OpenApiSpex.Schema{type: :object}},
      forbidden: {"Unauthorized", "application/json", %OpenApiSpex.Schema{type: :object}},
      not_found: {"File Not Found", "application/json", %OpenApiSpex.Schema{type: :object}}
    ]
  )

  def list_all_dropbox_pdfs(conn, params) do
    current_user = conn.assigns[:current_user]

    with {:ok, token} <- Integrations.get_latest_token(current_user, :dropbox),
         {:ok, pdfs} <- Dropbox.list_all_pdfs(token, params) do
      json(conn, %{"status" => "success", "pdfs" => pdfs["files"]})
    end
  end

  operation(:search_dropbox_files,
    summary: "Search Dropbox files",
    description: "Searches for files in Dropbox based on provided parameters",
    parameters: [
      query: [in: :query, type: :string, description: "Search query string", required: true],
      content_type: [
        in: :query,
        type: :string,
        description: "Filter by content type (e.g., \"application/pdf\")"
      ],
      limit: [
        in: :query,
        type: :integer,
        description: "Maximum number of results to return (default: 100)"
      ]
    ],
    responses: [
      ok: {"Success", "application/json", %OpenApiSpex.Schema{type: :object}},
      bad_request: {"Bad Request", "application/json", %OpenApiSpex.Schema{type: :object}},
      forbidden: {"Unauthorized", "application/json", %OpenApiSpex.Schema{type: :object}}
    ]
  )

  def search_dropbox_files(conn, params) do
    current_user = conn.assigns[:current_user]

    with {:ok, token} <- Integrations.get_latest_token(current_user, :dropbox),
         {:ok, results} <- Dropbox.search_files(token, params) do
      json(conn, %{"status" => "success", "results" => results})
    end
  end

  operation(:sync_dropbox_files,
    summary: "Sync Dropbox files with database",
    description: "Synchronizes files from Dropbox with the application database",
    parameters: [
      path: [in: :query, type: :string, description: "Path to synchronize files from"],
      recursive: [
        in: :query,
        type: :boolean,
        description: "Whether to synchronize files recursively"
      ]
    ],
    responses: [
      ok: {"Success", "application/json", %OpenApiSpex.Schema{type: :object}},
      bad_request: {"Bad Request", "application/json", %OpenApiSpex.Schema{type: :object}},
      forbidden: {"Unauthorized", "application/json", %OpenApiSpex.Schema{type: :object}}
    ]
  )

  def sync_dropbox_files(conn, params) do
    current_user = conn.assigns[:current_user]

    with {:ok, token} <- Integrations.get_latest_token(current_user, :dropbox),
         {:ok, result} <- Dropbox.sync_files_to_db(token, params, current_user) do
      json(conn, %{"status" => "success", "sync_result" => result})
    end
  end

  operation(:download_dropbox_file,
    summary: "Download files from Dropbox",
    description:
      "Downloads files from Dropbox based on provided file IDs and schedules the downloads",
    request_body: {"File IDs to download", "application/json", CloudImportSchema.DownloadRequest},
    responses: [
      accepted: {"Accepted", "application/json", %OpenApiSpex.Schema{type: :object}},
      bad_request: {"Bad Request", "application/json", %OpenApiSpex.Schema{type: :object}},
      forbidden: {"Unauthorized", "application/json", %OpenApiSpex.Schema{type: :object}}
    ]
  )

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

  operation(:list_dropbox_folders,
    summary: "List Dropbox folders",
    description: "Lists all folders in the user's Dropbox account",
    parameters: [
      path: [in: :query, type: :string, description: "Path to list folders from (default: \"\")"],
      recursive: [in: :query, type: :boolean, description: "Whether to list folders recursively"]
    ],
    responses: [
      ok: {"Success", "application/json", %OpenApiSpex.Schema{type: :object}},
      bad_request: {"Bad Request", "application/json", %OpenApiSpex.Schema{type: :object}},
      forbidden: {"Unauthorized", "application/json", %OpenApiSpex.Schema{type: :object}}
    ]
  )

  def list_dropbox_folders(conn, params) do
    current_user = conn.assigns[:current_user]

    with {:ok, token} <- Integrations.get_latest_token(current_user, :dropbox),
         {:ok, folders} <- Dropbox.list_all_folders(token, params) do
      json(conn, %{"status" => "success", "folders" => folders["folders"]})
    end
  end

  operation(:search_dropbox_folders,
    summary: "Search Dropbox folders",
    description: "Searches for folders in Dropbox based on provided parameters",
    parameters: [
      query: [in: :query, type: :string, description: "Search query string", required: true],
      max_results: [
        in: :query,
        type: :integer,
        description: "Maximum number of results to return (default: 100)"
      ]
    ],
    responses: [
      ok: {"Success", "application/json", %OpenApiSpex.Schema{type: :object}},
      bad_request: {"Bad Request", "application/json", %OpenApiSpex.Schema{type: :object}},
      forbidden: {"Unauthorized", "application/json", %OpenApiSpex.Schema{type: :object}}
    ]
  )

  def search_dropbox_folders(conn, params) do
    current_user = conn.assigns[:current_user]

    with {:ok, token} <- Integrations.get_latest_token(current_user, :dropbox),
         {:ok, results} <- Dropbox.search_folders(token, params) do
      json(conn, %{"status" => "success", "folders" => results["folders"]})
    end
  end

  operation(:get_dropbox_folder,
    summary: "Get Dropbox folder metadata",
    description: "Retrieves metadata for a specific folder in Dropbox",
    parameters: [
      folder_path: [
        in: :path,
        type: :string,
        description: "Path of the folder in Dropbox",
        required: true
      ]
    ],
    responses: [
      ok: {"Success", "application/json", %OpenApiSpex.Schema{type: :object}},
      bad_request: {"Bad Request", "application/json", %OpenApiSpex.Schema{type: :object}},
      forbidden: {"Unauthorized", "application/json", %OpenApiSpex.Schema{type: :object}},
      not_found: {"Folder Not Found", "application/json", %OpenApiSpex.Schema{type: :object}}
    ]
  )

  def get_dropbox_folder(conn, %{"folder_path" => folder_path}) do
    current_user = conn.assigns[:current_user]

    with {:ok, token} <- Integrations.get_latest_token(current_user, :dropbox),
         {:ok, metadata} <- Dropbox.get_folder_metadata(token, folder_path) do
      json(conn, %{"status" => "success", "folder_metadata" => metadata})
    end
  end

  # OneDrive Operations

  operation(:list_onedrive_files,
    summary: "List OneDrive files",
    description: "Lists all files in the user's OneDrive account",
    parameters: [
      path: [
        in: :query,
        type: :string,
        description: "Path to list files from (default: \"/drive/root/children\")"
      ],
      query: [in: :query, type: :string, description: "Filter query"]
    ],
    responses: [
      ok: {"Success", "application/json", %OpenApiSpex.Schema{type: :object}},
      bad_request: {"Bad Request", "application/json", %OpenApiSpex.Schema{type: :object}},
      forbidden: {"Unauthorized", "application/json", %OpenApiSpex.Schema{type: :object}}
    ]
  )

  def list_onedrive_files(conn, params) do
    current_user = conn.assigns[:current_user]

    with {:ok, token} <- Integrations.get_latest_token(current_user, :onedrive),
         {:ok, files} <- Onedrive.list_all_files(token, params) do
      json(conn, %{"status" => "success", "files" => files["files"]})
    end
  end

  operation(:get_onedrive_file,
    summary: "Get OneDrive file metadata",
    description: "Retrieves metadata for a specific file in OneDrive",
    parameters: [
      file_id: [
        in: :path,
        type: :string,
        description: "The ID of the file in OneDrive",
        required: true
      ]
    ],
    responses: [
      ok: {"Success", "application/json", %OpenApiSpex.Schema{type: :object}},
      bad_request: {"Bad Request", "application/json", %OpenApiSpex.Schema{type: :object}},
      forbidden: {"Unauthorized", "application/json", %OpenApiSpex.Schema{type: :object}},
      not_found: {"File Not Found", "application/json", %OpenApiSpex.Schema{type: :object}}
    ]
  )

  def get_onedrive_file(conn, %{"file_id" => file_id}) do
    current_user = conn.assigns[:current_user]

    with {:ok, token} <- Integrations.get_latest_token(current_user, :onedrive),
         {:ok, metadata} <- Onedrive.get_file_metadata(token, file_id) do
      json(conn, %{"status" => "success", "file_metadata" => metadata})
    end
  end

  operation(:list_all_onedrive_pdfs,
    summary: "List all PDF files in OneDrive",
    description: "Lists all PDF files in the user's OneDrive account",
    parameters: [
      top: [
        in: :query,
        type: :integer,
        description: "Maximum number of results to return (default: 1000)"
      ]
    ],
    responses: [
      ok: {"Success", "application/json", %OpenApiSpex.Schema{type: :object}},
      bad_request: {"Bad Request", "application/json", %OpenApiSpex.Schema{type: :object}},
      forbidden: {"Unauthorized", "application/json", %OpenApiSpex.Schema{type: :object}}
    ]
  )

  def list_all_onedrive_pdfs(conn, params) do
    current_user = conn.assigns[:current_user]

    with {:ok, token} <- Integrations.get_latest_token(current_user, :onedrive),
         {:ok, pdfs} <- Onedrive.list_all_pdfs(token, params) do
      json(conn, %{"status" => "success", "pdfs" => pdfs["files"]})
    end
  end

  operation(:search_onedrive_files,
    summary: "Search OneDrive files",
    description: "Searches for files in OneDrive based on provided parameters",
    parameters: [
      query: [in: :query, type: :string, description: "Search query string", required: true],
      content_type: [
        in: :query,
        type: :string,
        description: "Filter by content type (e.g., \"application/pdf\")"
      ],
      limit: [
        in: :query,
        type: :integer,
        description: "Maximum number of results to return (default: 100)"
      ]
    ],
    responses: [
      ok: {"Success", "application/json", %OpenApiSpex.Schema{type: :object}},
      bad_request: {"Bad Request", "application/json", %OpenApiSpex.Schema{type: :object}},
      forbidden: {"Unauthorized", "application/json", %OpenApiSpex.Schema{type: :object}}
    ]
  )

  def search_onedrive_files(conn, params) do
    current_user = conn.assigns[:current_user]

    with {:ok, token} <- Integrations.get_latest_token(current_user, :onedrive),
         {:ok, results} <- Onedrive.search_files(token, params) do
      json(conn, %{"status" => "success", "results" => results})
    end
  end

  operation(:sync_onedrive_files,
    summary: "Sync OneDrive files with database",
    description: "Synchronizes files from OneDrive with the application database",
    parameters: [
      path: [in: :query, type: :string, description: "Path to synchronize files from"],
      recursive: [
        in: :query,
        type: :boolean,
        description: "Whether to synchronize files recursively"
      ]
    ],
    responses: [
      ok: {"Success", "application/json", %OpenApiSpex.Schema{type: :object}},
      bad_request: {"Bad Request", "application/json", %OpenApiSpex.Schema{type: :object}},
      forbidden: {"Unauthorized", "application/json", %OpenApiSpex.Schema{type: :object}}
    ]
  )

  def sync_onedrive_files(conn, params) do
    current_user = conn.assigns[:current_user]

    with {:ok, token} <- Integrations.get_latest_token(current_user, :onedrive),
         {:ok, result} <- Onedrive.sync_files_to_db(token, params, current_user) do
      json(conn, %{"status" => "success", "sync_result" => result})
    end
  end

  operation(:download_onedrive_file,
    summary: "Download files from OneDrive",
    description:
      "Downloads files from OneDrive based on provided file IDs and schedules the downloads",
    request_body: {"File IDs to download", "application/json", CloudImportSchema.DownloadRequest},
    responses: [
      accepted: {"Accepted", "application/json", %OpenApiSpex.Schema{type: :object}},
      bad_request: {"Bad Request", "application/json", %OpenApiSpex.Schema{type: :object}},
      forbidden: {"Unauthorized", "application/json", %OpenApiSpex.Schema{type: :object}}
    ]
  )

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

  operation(:list_onedrive_folders,
    summary: "List OneDrive folders",
    description: "Lists all folders in the user's OneDrive account",
    parameters: [
      path: [
        in: :query,
        type: :string,
        description: "Path to list folders from (default: \"/drive/root/children\")"
      ]
    ],
    responses: [
      ok: {"Success", "application/json", %OpenApiSpex.Schema{type: :object}},
      bad_request: {"Bad Request", "application/json", %OpenApiSpex.Schema{type: :object}},
      forbidden: {"Unauthorized", "application/json", %OpenApiSpex.Schema{type: :object}}
    ]
  )

  def list_onedrive_folders(conn, params) do
    current_user = conn.assigns[:current_user]

    with {:ok, token} <- Integrations.get_latest_token(current_user, :onedrive),
         {:ok, folders} <- Onedrive.list_all_folders(token, params) do
      json(conn, %{"status" => "success", "folders" => folders["folders"]})
    end
  end

  operation(:search_onedrive_folders,
    summary: "Search OneDrive folders",
    description: "Searches for folders in OneDrive based on provided parameters",
    parameters: [
      query: [in: :query, type: :string, description: "Search query string", required: true],
      top: [
        in: :query,
        type: :integer,
        description: "Maximum number of results to return (default: 100)"
      ]
    ],
    responses: [
      ok: {"Success", "application/json", %OpenApiSpex.Schema{type: :object}},
      bad_request: {"Bad Request", "application/json", %OpenApiSpex.Schema{type: :object}},
      forbidden: {"Unauthorized", "application/json", %OpenApiSpex.Schema{type: :object}}
    ]
  )

  def search_onedrive_folders(conn, params) do
    current_user = conn.assigns[:current_user]

    with {:ok, token} <- Integrations.get_latest_token(current_user, :onedrive),
         {:ok, results} <- Onedrive.search_folders(token, params) do
      json(conn, %{"status" => "success", "folders" => results["folders"]})
    end
  end

  operation(:list_onedrive_folder_files,
    summary: "List files in OneDrive folder",
    description: "Lists all files within a specific folder in OneDrive",
    parameters: [
      folder_id: [
        in: :path,
        type: :string,
        description: "The ID of the folder in OneDrive",
        required: true
      ],
      top: [
        in: :query,
        type: :integer,
        description: "Maximum number of results to return (default: 1000)"
      ],
      file_type: [
        in: :query,
        type: :string,
        description: "Filter by file type (pdf, image, document, all)"
      ]
    ],
    responses: [
      ok: {"Success", "application/json", %OpenApiSpex.Schema{type: :object}},
      bad_request: {"Bad Request", "application/json", %OpenApiSpex.Schema{type: :object}},
      forbidden: {"Unauthorized", "application/json", %OpenApiSpex.Schema{type: :object}},
      not_found: {"Folder Not Found", "application/json", %OpenApiSpex.Schema{type: :object}}
    ]
  )

  def list_onedrive_folder_files(conn, %{"folder_id" => folder_id} = params) do
    current_user = conn.assigns[:current_user]

    with {:ok, token} <- Integrations.get_latest_token(current_user, :onedrive),
         {:ok, files} <- Onedrive.list_files_in_folder(token, folder_id, params) do
      json(conn, %{"status" => "success", "files" => files["files"]})
    end
  end

  operation(:get_onedrive_folder,
    summary: "Get OneDrive folder metadata",
    description: "Retrieves metadata for a specific folder in OneDrive",
    parameters: [
      folder_id: [
        in: :path,
        type: :string,
        description: "The ID of the folder in OneDrive",
        required: true
      ]
    ],
    responses: [
      ok: {"Success", "application/json", %OpenApiSpex.Schema{type: :object}},
      bad_request: {"Bad Request", "application/json", %OpenApiSpex.Schema{type: :object}},
      forbidden: {"Unauthorized", "application/json", %OpenApiSpex.Schema{type: :object}},
      not_found: {"Folder Not Found", "application/json", %OpenApiSpex.Schema{type: :object}}
    ]
  )

  def get_onedrive_folder(conn, %{"folder_id" => folder_id}) do
    current_user = conn.assigns[:current_user]

    with {:ok, token} <- Integrations.get_latest_token(current_user, :onedrive),
         {:ok, metadata} <- Onedrive.get_folder_metadata(token, folder_id) do
      json(conn, %{"status" => "success", "folder_metadata" => metadata})
    end
  end
end
