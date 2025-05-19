defmodule WraftDocWeb.CloudServiceController do
  @moduledoc """
  Controller for handling cloud service interactions, primarily with Google Drive.
  Provides endpoints for authentication, file exploration, and file operations.
  """

  use WraftDocWeb, :controller
  alias WraftDoc.AuthTokens
  alias WraftDoc.CloudService.{CloudAuth, Clouds}

  @doc """
  Redirects to Google OAuth login URL.
  """
  def login_url(conn, _params) do
    redirect(conn, external: CloudAuth.authorize_url!())
  end

  @doc """
  Handles OAuth callback from Google. Creates an auth token on successful authentication.
  """
  def callback(conn, %{"code" => code}) do
    case CloudAuth.get_token(code) do
      {:ok, token_data} ->
        create_token_and_redirect(conn, token_data)

      {:error, reason} ->
        conn
        |> put_flash(:error, "Authentication failed: #{inspect(reason)}")
        |> redirect(to: "/")
    end
  end

  @doc """
  Returns the current authentication status.
  """
  def status(conn, _params) do
    token = get_session(conn, :google_token)

    if token do
      json(conn, %{
        authenticated: true,
        scope: get_session(conn, :google_token_scope)
      })
    else
      json(conn, %{authenticated: false})
    end
  end

  @doc """
  Logs out the user by clearing the session.
  """
  def logout(conn, _params) do
    conn
    |> clear_session()
    |> json(%{status: "success", message: "Logged out successfully"})
  end

  @doc """
  File explorer view - shows folders first, then files in a hierarchical structure.
  """
  def explorer(conn, params) do
    token = AuthTokens.get_latest_token(:google_oauth)
    parent_id = Map.get(params, "folder_id", "root")
    page_size = params |> Map.get("page_size", "100") |> String.to_integer()

    case Clouds.explorer(token, parent_id, page_size) do
      {:ok, result} ->
        json(conn, Map.put(result, "status", "success"))

      {:error, reason} ->
        handle_error(conn, reason)
    end
  end

  @doc """
  Get breadcrumb path to a folder for navigation.
  """
  def folder_path(conn, %{"folder_id" => folder_id}) do
    token = AuthTokens.get_latest_token(:google_oauth)

    case Clouds.folder_path(token, folder_id) do
      {:ok, result} ->
        json(conn, Map.put(result, "status", "success"))

      {:error, reason} ->
        handle_error(conn, reason)
    end
  end

  @doc """
  List files in Google Drive with optional query parameters.
  """
  def list_files(conn, params) do
    token = AuthTokens.get_latest_token(:google_oauth)
    page_size = params |> Map.get("page_size", "30") |> String.to_integer()
    query = Map.get(params, "query", "")

    case Clouds.list_files(token, query, page_size) do
      {:ok, %{"files" => files}} ->
        json(conn, %{"status" => "success", "files" => files})

      {:error, reason} ->
        handle_error(conn, reason)
    end
  end

  @doc """
  Get metadata for a specific file.
  """
  def get_file(conn, %{"file_id" => file_id}) do
    token = AuthTokens.get_latest_token(:google_oauth)

    case Clouds.get_file_metadata(token, file_id) do
      {:ok, metadata} ->
        json(conn, %{"status" => "success", "file_metadata" => metadata})

      {:error, reason} ->
        handle_error(conn, reason)
    end
  end

  @doc """
  Download a file from Google Drive.
  Gets the file metadata first to determine the correct filename and MIME type.
  """
  def download_file(conn, %{"file_id" => file_id}) do
    token = AuthTokens.get_latest_token(:google_oauth)

    case Clouds.download_file(token, file_id) do
      {:ok, %{content: body, metadata: metadata}} ->
        filename = metadata["name"]
        mime_type = metadata["mimeType"]

        if String.starts_with?(mime_type, "application/vnd.google-apps.") do
          export_google_workspace_file(conn, token, file_id, mime_type, filename)
        else
          send_file_response(conn, filename, mime_type, body)
        end

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: translate_errors(changeset)})

      {:error, reason} ->
        handle_error(conn, reason)
    end
  end

  @doc """
  Translates Ecto changeset errors into a map of messages.
  """
  def translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end

  @doc """
  Export a file from Google Docs to another format.
  """
  def export_file(conn, %{"file_id" => file_id, "mime_type" => mime_type}) do
    token = AuthTokens.get_latest_token(:google_oauth)

    case Clouds.export_file(token, file_id, mime_type) do
      {:ok, %{content: body, metadata: metadata}} ->
        filename = metadata["name"]
        extension = metadata["exportExtension"]

        filename_with_extension =
          if Path.extname(filename) == "", do: filename <> extension, else: filename

        send_file_response(conn, filename_with_extension, mime_type, body)

      {:error, reason} ->
        handle_error(conn, reason)
    end
  end

  @doc """
  List all folders in Google Drive.
  """
  def list_all_folders(conn, params) do
    token = AuthTokens.get_latest_token(:google_oauth)
    page_size = params |> Map.get("page_size", "100") |> String.to_integer()

    case Clouds.list_all_folders(token, page_size) do
      {:ok, %{"files" => folders}} ->
        json(conn, %{"status" => "success", "folders" => folders})

      {:error, reason} ->
        handle_error(conn, reason)
    end
  end

  @doc """
  List files in a specific folder.
  """
  def list_files_in_folder(conn, %{"folder_id" => folder_id}) do
    token = AuthTokens.get_latest_token(:google_oauth)
    page_size = conn.query_params |> Map.get("page_size", "50") |> String.to_integer()
    query = "'#{folder_id}' in parents"

    case Clouds.list_files(token, query, page_size) do
      {:ok, %{"files" => files}} ->
        json(conn, %{"status" => "success", "files" => files})

      {:error, reason} ->
        handle_error(conn, reason)
    end
  end

  @doc """
  Search for files in Google Drive by name.
  """
  def search_files(conn, %{"search_term" => search_term} = params) do
    token = AuthTokens.get_latest_token(:google_oauth)
    mime_type = Map.get(params, "mime_type")
    page_size = params |> Map.get("page_size", "30") |> String.to_integer()

    case Clouds.search_files(token, search_term, mime_type, page_size) do
      {:ok, %{"files" => files}} ->
        json(conn, %{"status" => "success", "files" => files})

      {:error, reason} ->
        handle_error(conn, reason)
    end
  end

  @doc """
  Search for folders by name.
  """
  def search_folders(conn, %{"search_term" => search_term} = params) do
    token = AuthTokens.get_latest_token(:google_oauth)
    page_size = params |> Map.get("page_size", "30") |> String.to_integer()

    case Clouds.search_folders(token, search_term, page_size) do
      {:ok, %{"files" => folders}} ->
        json(conn, %{"status" => "success", "folders" => folders})

      {:error, reason} ->
        handle_error(conn, reason)
    end
  end

  @doc """
  List all PDF files in Google Drive.
  """
  def list_all_pdfs(conn, params) do
    token = AuthTokens.get_latest_token(:google_oauth)
    page_size = params |> Map.get("page_size", "100") |> String.to_integer()

    case Clouds.list_all_pdfs(token, page_size) do
      {:ok, %{"files" => pdfs}} ->
        json(conn, %{"status" => "success", "pdfs" => pdfs})

      {:error, reason} ->
        handle_error(conn, reason)
    end
  end

  # Private functions

  defp create_token_and_redirect(conn, %{
         access_token: access_token,
         refresh_token: refresh_token,
         expires_in: expires_in,
         scope: scope,
         token_type: token_type
       }) do
    attrs = %{
      value: access_token,
      token_type: :google_oauth,
      expiry_datetime: NaiveDateTime.add(NaiveDateTime.utc_now(), expires_in),
      meta_data: %{
        "scope" => scope,
        "refresh_token" => refresh_token,
        "token_type" => token_type
      }
    }

    {:ok, _token} = AuthTokens.create_token(attrs)
    redirect(conn, to: "/")
  end

  # Helper function to export Google Workspace files
  defp export_google_workspace_file(conn, token, file_id, source_mime_type, filename) do
    # Map Google Workspace MIME types to export MIME types
    {export_mime_type, extension} = get_export_format(source_mime_type)

    # Ensure filename has the correct extension
    filename_with_extension =
      if Path.extname(filename) == "", do: filename <> extension, else: filename

    case Clouds.export_file(token, file_id, export_mime_type) do
      {:ok, %{content: body}} ->
        send_file_response(conn, filename_with_extension, export_mime_type, body)

      {:error, reason} ->
        handle_error(conn, reason)
    end
  end

  # Maps Google Workspace MIME types to export formats
  defp get_export_format(source_mime_type) do
    case source_mime_type do
      "application/vnd.google-apps.document" ->
        {"application/pdf", ".pdf"}

      "application/vnd.google-apps.spreadsheet" ->
        {"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", ".xlsx"}

      "application/vnd.google-apps.presentation" ->
        {"application/vnd.openxmlformats-officedocument.presentationml.presentation", ".pptx"}

      "application/vnd.google-apps.drawing" ->
        {"application/pdf", ".pdf"}

      # Default to PDF for other formats
      _ ->
        {"application/pdf", ".pdf"}
    end
  end

  # Helper to send file response with proper headers
  defp send_file_response(conn, filename, mime_type, body) do
    conn
    |> put_resp_header("content-disposition", ~s(attachment; filename="#{filename}"))
    |> put_resp_content_type(mime_type)
    |> send_resp(200, body)
  end

  # Standardized error handler
  defp handle_error(conn, %{status: status, body: body}) do
    conn
    |> put_status(status)
    |> json(%{"status" => "error", "message" => body})
  end

  defp handle_error(conn, reason) do
    conn
    |> put_status(:internal_server_error)
    |> json(%{"status" => "error", "message" => inspect(reason)})
  end
end
