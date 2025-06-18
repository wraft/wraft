defmodule WraftDocWeb.Api.V1.CloudImportController do
  @moduledoc """
  Controller for handling cloud service interactions with Google Drive, Dropbox, and OneDrive.
  Provides fully independent endpoint implementations for each service.
  """
  use WraftDocWeb, :controller

  alias WraftDoc.CloudImport.CloudAuthTokens, as: AuthTokens
  alias WraftDoc.CloudImport.Clouds

  action_fallback(WraftDocWeb.FallbackController)

  require Logger

  # Google Drive endpoints
  @doc """
  Lists all files in Google Drive.
  """
  def list_gdrive_files(conn, params) do
    current_user = conn.assigns[:current_user]

    with token when not is_nil(token) <- AuthTokens.get_latest_token(current_user, :google_oauth),
         {:ok, files} <- Clouds.list_all_files(:google_drive, token, params) do
      json(conn, %{"status" => "success", "files" => files["files"]})
    end
  end

  @doc """
  Retrieves metadata for a specific file in Google Drive.
  """
  def get_gdrive_file(conn, %{"file_id" => file_id}) do
    current_user = conn.assigns[:current_user]

    with token when not is_nil(token) <- AuthTokens.get_latest_token(current_user, :google_oauth),
         {:ok, metadata} <- Clouds.get_file_metadata(:google_drive, token, file_id) do
      json(conn, %{"status" => "success", "file_metadata" => metadata})
    end
  end

  @doc """
  Lists all PDF files in Google Drive.
  """
  def list_all_gdrive_pdfs(conn, params) do
    current_user = conn.assigns[:current_user]

    with token when not is_nil(token) <- AuthTokens.get_latest_token(current_user, :google_oauth),
         {:ok, pdfs} <- Clouds.list_all_pdfs(:google_drive, token, params) do
      json(conn, %{"status" => "success", "pdfs" => pdfs["files"]})
    end
  end

  @doc """
  Searches for files in Google Drive based on provided parameters.
  """
  def search_gdrive_files(conn, params) do
    current_user = conn.assigns[:current_user]

    with token when not is_nil(token) <- AuthTokens.get_latest_token(current_user, :google_oauth),
         {:ok, results} <- Clouds.search_files(:google_drive, token, params) do
      json(conn, %{"status" => "success", "results" => results})
    end
  end

  @doc """
  Synchronizes Google Drive files with the database.
  """
  def sync_gdrive_files(conn, _params) do
    current_user = conn.assigns[:current_user]

    with token when not is_nil(token) <- AuthTokens.get_latest_token(current_user, :google_oauth),
         {:ok, result} <- Clouds.sync_files_to_db(:google_drive, token) do
      json(conn, %{"status" => "success", "sync_result" => result})
    end
  end

  @doc """
  Downloads files from Google Drive based on provided file IDs.
  This endpoint accepts a list of file IDs and schedules downloads.
  """
  def download_gdrive_file(conn, %{"file_ids" => file_ids}) do
    user = conn.assigns[:current_user]
    # need to be changed
    org = conn.assigns[:current_org]

    with token when not is_nil(token) <- AuthTokens.get_latest_token(user, :google_oauth) do
      results = Clouds.schedule_download_to_minio(:google_drive, token, file_ids, user.id, org.id)

      conn
      |> put_status(:accepted)
      |> json(%{
        status: "processing",
        service: "google_drive",
        results: results
      })
    end
  end

  # Dropbox endpoints
  @doc """
  Lists all files in Dropbox.
  """
  def list_dropbox_files(conn, params) do
    current_user = conn.assigns[:current_user]

    with token when not is_nil(token) <- AuthTokens.get_latest_token(current_user, :dropbox),
         {:ok, files} <- Clouds.list_all_files(:dropbox, token, params) do
      json(conn, %{"status" => "success", "files" => files["files"]})
    end
  end

  @doc """
  Retrieves metadata for a specific file in Dropbox.
  """
  def get_dropbox_file(conn, %{"file_id" => file_id}) do
    current_user = conn.assigns[:current_user]

    with token when not is_nil(token) <- AuthTokens.get_latest_token(current_user, :dropbox),
         {:ok, metadata} <- Clouds.get_file_metadata(:dropbox, token, file_id) do
      json(conn, %{"status" => "success", "file_metadata" => metadata})
    end
  end

  @doc """
  Lists all PDF files in Dropbox.
  """
  def list_all_dropbox_pdfs(conn, params) do
    current_user = conn.assigns[:current_user]

    with token when not is_nil(token) <- AuthTokens.get_latest_token(current_user, :dropbox),
         {:ok, pdfs} <- Clouds.list_all_pdfs(:dropbox, token, params) do
      json(conn, %{"status" => "success", "pdfs" => pdfs["files"]})
    end
  end

  @doc """
  Searches for files in Dropbox based on provided parameters.
  """
  def search_dropbox_files(conn, params) do
    current_user = conn.assigns[:current_user]

    with token when not is_nil(token) <- AuthTokens.get_latest_token(current_user, :dropbox),
         {:ok, results} <- Clouds.search_files(:dropbox, token, params) do
      json(conn, %{"status" => "success", "results" => results})
    end
  end

  @doc """
  Synchronizes Dropbox files with the database.
  """
  def sync_dropbox_files(conn, _params) do
    current_user = conn.assigns[:current_user]

    with token when not is_nil(token) <- AuthTokens.get_latest_token(current_user, :dropbox),
         {:ok, result} <- Clouds.sync_files_to_db(:dropbox, token) do
      json(conn, %{"status" => "success", "sync_result" => result})
    end
  end

  @doc """
  Downloads files from Dropbox based on provided file IDs.
  This endpoint accepts a list of file IDs and schedules downloads.
  """
  def download_dropbox_file(conn, %{"file_ids" => file_ids}) do
    user = conn.assigns[:current_user]
    # need to be changed""
    org = conn.assigns[:current_org]

    with token when not is_nil(token) <- AuthTokens.get_latest_token(user, :dropbox) do
      results = Clouds.schedule_download_to_minio(:dropbox, token, file_ids, user.id, org.id)

      conn
      |> put_status(:accepted)
      |> json(%{
        status: "processing",
        service: "dropbox",
        results: results
      })
    end
  end

  # OneDrive endpoints
  @doc """
  Lists all files in OneDrive.
  """
  def list_onedrive_files(conn, params) do
    current_user = conn.assigns[:current_user]

    with token when not is_nil(token) <- AuthTokens.get_latest_token(current_user, :onedrive),
         {:ok, files} <- Clouds.list_all_files(:onedrive, token, params) do
      json(conn, %{"status" => "success", "files" => files["files"]})
    end
  end

  @doc """
  Retrieves metadata for a specific file in OneDrive.
  """
  def get_onedrive_file(conn, %{"file_id" => file_id}) do
    current_user = conn.assigns[:current_user]

    with token when not is_nil(token) <- AuthTokens.get_latest_token(current_user, :onedrive),
         {:ok, metadata} <- Clouds.get_file_metadata(:onedrive, token, file_id) do
      json(conn, %{"status" => "success", "file_metadata" => metadata})
    end
  end

  @doc """
  Lists all PDF files in OneDrive.
  """
  def list_all_onedrive_pdfs(conn, params) do
    current_user = conn.assigns[:current_user]

    with token when not is_nil(token) <- AuthTokens.get_latest_token(current_user, :onedrive),
         {:ok, pdfs} <- Clouds.list_all_pdfs(:onedrive, token, params) do
      json(conn, %{"status" => "success", "pdfs" => pdfs["files"]})
    end
  end

  @doc """
  Searches for files in OneDrive based on provided parameters.
  """
  def search_onedrive_files(conn, params) do
    current_user = conn.assigns[:current_user]

    with token when not is_nil(token) <- AuthTokens.get_latest_token(current_user, :onedrive),
         {:ok, results} <- Clouds.search_files(:onedrive, token, params) do
      json(conn, %{"status" => "success", "results" => results})
    end
  end

  @doc """
  Synchronizes OneDrive files with the database.
  """
  def sync_onedrive_files(conn, _params) do
    current_user = conn.assigns[:current_user]

    with token when not is_nil(token) <- AuthTokens.get_latest_token(current_user, :onedrive),
         {:ok, result} <- Clouds.sync_files_to_db(:onedrive, token) do
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
      results = Clouds.schedule_download_to_minio(:onedrive, token, file_ids, user.id, org.id)

      conn
      |> put_status(:accepted)
      |> json(%{
        status: "processing",
        service: "onedrive",
        results: results
      })
    end
  end

  # Google Drive folder endpoints
  @doc """
  Lists all folders in Google Drive.
  """
  def list_gdrive_folders(conn, params) do
    current_user = conn.assigns[:current_user]

    with token when not is_nil(token) <- AuthTokens.get_latest_token(current_user, :google_oauth),
         {:ok, folders} <- Clouds.list_all_folders(:google_drive, token, params) do
      json(conn, %{"status" => "success", "folders" => folders["files"]})
    end
  end

  @doc """
  Searches for folders in Google Drive based on provided parameters.
  """
  def search_gdrive_folders(conn, params) do
    current_user = conn.assigns[:current_user]

    with token when not is_nil(token) <- AuthTokens.get_latest_token(current_user, :google_oauth),
         {:ok, results} <- Clouds.search_folders(:google_drive, token, params) do
      json(conn, %{"status" => "success", "folders" => results["files"]})
    end
  end

  @doc """
  Lists all files within a specific Google Drive folder.
  """
  def list_gdrive_folder_files(conn, %{"folder_id" => folder_id} = params) do
    current_user = conn.assigns[:current_user]

    with token when not is_nil(token) <- AuthTokens.get_latest_token(current_user, :google_oauth),
         {:ok, files} <- Clouds.list_files_in_folder(:google_drive, token, folder_id, params) do
      json(conn, %{"status" => "success", "files" => files["files"]})
    end
  end

  @doc """
  Retrieves metadata for a specific folder in Google Drive.
  """
  def get_gdrive_folder(conn, %{"folder_id" => folder_id}) do
    current_user = conn.assigns[:current_user]

    with token when not is_nil(token) <- AuthTokens.get_latest_token(current_user, :google_oauth),
         {:ok, metadata} <- Clouds.get_folder_metadata(:google_drive, token, folder_id) do
      json(conn, %{"status" => "success", "folder_metadata" => metadata})
    end
  end

  # Dropbox folder endpoints
  @doc """
  Lists all folders in Dropbox.
  """
  def list_dropbox_folders(conn, params) do
    current_user = conn.assigns[:current_user]

    with token when not is_nil(token) <- AuthTokens.get_latest_token(current_user, :dropbox),
         {:ok, folders} <- Clouds.list_all_folders(:dropbox, token, params) do
      json(conn, %{"status" => "success", "folders" => folders["folders"]})
    end
  end

  @doc """
  Searches for folders in Dropbox based on provided parameters.
  """
  def search_dropbox_folders(conn, params) do
    current_user = conn.assigns[:current_user]

    with token when not is_nil(token) <- AuthTokens.get_latest_token(current_user, :dropbox),
         {:ok, results} <- Clouds.search_folders(:dropbox, token, params) do
      json(conn, %{"status" => "success", "folders" => results["folders"]})
    end
  end

  @doc """
  Lists all files within a specific Dropbox folder.
  """
  def list_dropbox_folder_files(conn, %{"folder_path" => folder_path} = params) do
    current_user = conn.assigns[:current_user]

    with token when not is_nil(token) <- AuthTokens.get_latest_token(current_user, :dropbox),
         {:ok, files} <- Clouds.list_files_in_folder(:dropbox, token, folder_path, params) do
      json(conn, %{"status" => "success", "files" => files["files"]})
    end
  end

  @doc """
  Retrieves metadata for a specific folder in Dropbox.
  """
  def get_dropbox_folder(conn, %{"folder_path" => folder_path}) do
    current_user = conn.assigns[:current_user]

    with token when not is_nil(token) <- AuthTokens.get_latest_token(current_user, :dropbox),
         {:ok, metadata} <- Clouds.get_folder_metadata(:dropbox, token, folder_path) do
      json(conn, %{"status" => "success", "folder_metadata" => metadata})
    end
  end

  # OneDrive folder endpoints
  @doc """
  Lists all folders in OneDrive.
  """
  def list_onedrive_folders(conn, params) do
    current_user = conn.assigns[:current_user]

    with token when not is_nil(token) <- AuthTokens.get_latest_token(current_user, :onedrive),
         {:ok, folders} <- Clouds.list_all_folders(:onedrive, token, params) do
      json(conn, %{"status" => "success", "folders" => folders["folders"]})
    end
  end

  @doc """
  Searches for folders in OneDrive based on provided parameters.
  """
  def search_onedrive_folders(conn, params) do
    current_user = conn.assigns[:current_user]

    with token when not is_nil(token) <- AuthTokens.get_latest_token(current_user, :onedrive),
         {:ok, results} <- Clouds.search_folders(:onedrive, token, params) do
      json(conn, %{"status" => "success", "folders" => results["folders"]})
    end
  end

  @doc """
  Lists all files within a specific OneDrive folder.
  """
  def list_onedrive_folder_files(conn, %{"folder_id" => folder_id} = params) do
    current_user = conn.assigns[:current_user]

    with token when not is_nil(token) <- AuthTokens.get_latest_token(current_user, :onedrive),
         {:ok, files} <- Clouds.list_files_in_folder(:onedrive, token, folder_id, params) do
      json(conn, %{"status" => "success", "files" => files["files"]})
    end
  end

  @doc """
  Retrieves metadata for a specific folder in OneDrive.
  """
  def get_onedrive_folder(conn, %{"folder_id" => folder_id}) do
    current_user = conn.assigns[:current_user]

    with token when not is_nil(token) <- AuthTokens.get_latest_token(current_user, :onedrive),
         {:ok, metadata} <- Clouds.get_folder_metadata(:onedrive, token, folder_id) do
      json(conn, %{"status" => "success", "folder_metadata" => metadata})
    end
  end
end
