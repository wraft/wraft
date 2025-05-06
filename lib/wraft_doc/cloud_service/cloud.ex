defmodule WraftDoc.GoogleDrive do
  @moduledoc """
  Core Google Drive functionality that can be tested directly from iex.
  This module handles authentication and basic API operations.
  """
  require Logger

  # @oauth_site "https://accounts.google.com"
  @oauth_authorize_url "https://accounts.google.com/o/oauth2/v2/auth"
  @oauth_token_url "https://oauth2.googleapis.com/token"
  @drive_api_base "https://www.googleapis.com/drive/v3"

  @doc """
  Initialize the module with configuration.

  ## Example
      iex> config = WraftDoc.GoogleDrive.init(%{
      ...>   client_id: System.get_env("GOOGLE_CLIENT_ID"),
      ...>   client_secret: System.get_env("GOOGLE_CLIENT_SECRET"),
      ...>   redirect_uri: "http://localhost:4000/oauth/callback/google_drive"
      ...> })
  """
  def init(opts \\ %{}) do
    %{
      client_id: opts[:client_id] || System.get_env("GOOGLE_CLIENT_ID"),
      client_secret: opts[:client_secret] || System.get_env("GOOGLE_CLIENT_SECRET"),
      redirect_uri:
        opts[:redirect_uri] || System.get_env("GOOGLE_REDIRECT_URI") ||
          "http://localhost:4000/api/v1/oauth/callback/google_drive",
      scope:
        opts[:scope] ||
          "https://www.googleapis.com/auth/drive.file https://www.googleapis.com/auth/drive.readonly"
    }
  end

  @doc """
  Generate an authorization URL for OAuth flow.

  ## Example
      iex> config = WraftDoc.GoogleDrive.init()
      iex> WraftDoc.GoogleDrive.get_authorize_url(config)
      "https://accounts.google.com/o/oauth2/v2/auth?client_id=..."
  """
  def get_authorize_url do
    config = init()

    params =
      URI.encode_query(%{
        client_id: config.client_id,
        redirect_uri: config.redirect_uri,
        response_type: "code",
        access_type: "offline",
        prompt: "consent",
        scope: config.scope
      })

    "#{@oauth_authorize_url}?#{params}"
  end

  @doc """
  Exchange an authorization code for access and refresh tokens.

  ## Example
      iex> config = WraftDoc.GoogleDrive.init()
      iex> {:ok, tokens} = WraftDoc.GoogleDrive.exchange_code_for_token(config, "authorization_code_from_callback")
      iex> tokens.access_token
      "ya29.a0AVvZ..."
  """
  def exchange_code_for_token(code) do
    config = init()

    headers = [
      {"Content-Type", "application/x-www-form-urlencoded"}
    ]

    body =
      URI.encode_query(%{
        code: code,
        client_id: config.client_id,
        client_secret: config.client_secret,
        redirect_uri: config.redirect_uri,
        grant_type: "authorization_code"
      })

    case HTTPoison.post(@oauth_token_url, body, headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
        tokens = Jason.decode!(response_body)

        {:ok,
         %{
           access_token: tokens["access_token"],
           refresh_token: tokens["refresh_token"],
           expires_in: tokens["expires_in"],
           expires_at: :os.system_time(:second) + tokens["expires_in"]
         }}

      {:ok, %HTTPoison.Response{status_code: status_code, body: response_body}} ->
        {:error, "Failed to exchange code: HTTP #{status_code}, #{response_body}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, "HTTP error: #{inspect(reason)}"}
    end
  end

  @doc """
  Refresh an expired access token using a refresh token.

  ## Example
      iex> config = WraftDoc.GoogleDrive.init()
      iex> {:ok, new_tokens} = WraftDoc.GoogleDrive.refresh_token(config, "refresh_token_value")
  """
  def refresh_token(refresh_token) do
    config = init()

    headers = [
      {"Content-Type", "application/x-www-form-urlencoded"}
    ]

    body =
      URI.encode_query(%{
        refresh_token: refresh_token,
        client_id: config.client_id,
        client_secret: config.client_secret,
        grant_type: "refresh_token"
      })

    case HTTPoison.post(@oauth_token_url, body, headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
        tokens = Jason.decode!(response_body)

        {:ok,
         %{
           access_token: tokens["access_token"],
           # Google doesn't always return a new refresh token
           refresh_token: tokens["refresh_token"] || refresh_token,
           expires_in: tokens["expires_in"],
           expires_at: :os.system_time(:second) + tokens["expires_in"]
         }}

      {:ok, %HTTPoison.Response{status_code: status_code, body: response_body}} ->
        {:error, "Failed to refresh token: HTTP #{status_code}, #{response_body}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, "HTTP error: #{inspect(reason)}"}
    end
  end

  @doc """
  Verify if an access token is valid by making a simple API call.

  ## Example
      iex> WraftDoc.GoogleDrive.verify_token("your_access_token")
      {:ok, :valid}
  """
  def verify_token(access_token) do
    url = "#{@drive_api_base}/about?fields=user"
    headers = [{"Authorization", "Bearer #{access_token}"}]

    case HTTPoison.get(url, headers) do
      {:ok, %HTTPoison.Response{status_code: 200}} ->
        {:ok, :valid}

      {:ok, %HTTPoison.Response{status_code: 401}} ->
        {:error, :token_expired}

      {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
        {:error, "API error: HTTP #{status_code}, #{body}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, "HTTP error: #{inspect(reason)}"}
    end
  end

  @doc """
  List files from Google Drive.

  ## Example
      iex> WraftDoc.GoogleDrive.list_files("your_access_token")
      {:ok, %{"files" => [%{"id" => "abc123", "name" => "document.docx"}, ...]}}
  """
  def list_files(access_token, opts \\ %{}) do
    params = %{
      fields: "files(id,name,mimeType)",
      pageSize: opts[:limit] || 10
    }

    # Add search query if provided
    params = if opts[:query], do: Map.put(params, :q, opts[:query]), else: params

    url = "#{@drive_api_base}/files?#{URI.encode_query(params)}"

    headers = [
      {"Authorization", "Bearer #{access_token}"},
      {"Accept", "application/json"}
    ]

    case HTTPoison.get(url, headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, Jason.decode!(body)}

      {:ok, %HTTPoison.Response{status_code: 401}} ->
        {:error, :token_expired}

      {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
        {:error, "API error: HTTP #{status_code}, #{body}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, "HTTP error: #{inspect(reason)}"}
    end
  end

  @doc """
  Get a specific file's metadata.

  ## Example
      iex> WraftDoc.GoogleDrive.get_file("file_id", "your_access_token")
      {:ok, %{"id" => "file_id", "name" => "document.docx", ...}}
  """
  def get_file(file_id, access_token) do
    url = "#{@drive_api_base}/files/#{file_id}?fields=id,name,mimeType,size,modifiedTime"

    headers = [
      {"Authorization", "Bearer #{access_token}"},
      {"Accept", "application/json"}
    ]

    case HTTPoison.get(url, headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, Jason.decode!(body)}

      {:ok, %HTTPoison.Response{status_code: 401}} ->
        {:error, :token_expired}

      {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
        {:error, "API error: HTTP #{status_code}, #{body}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, "HTTP error: #{inspect(reason)}"}
    end
  end
end
