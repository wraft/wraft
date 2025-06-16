defmodule WraftDoc.CloudImport.CloudAuth do
  @moduledoc """
  Handles OAuth2 authentication for Google Drive, Dropbox, and OneDrive.

  Provides functions for:
  - Generating authorization URLs
  - Exchanging authorization codes for tokens
  - Refreshing access tokens
  """

  require Logger
  alias OAuth2.AccessToken
  alias OAuth2.Client

  @scopes %{
    # Google Drive scopes
    google_drive: "https://www.googleapis.com/auth/drive",
    google_drive_readonly: "https://www.googleapis.com/auth/drive.readonly",
    google_drive_file: "https://www.googleapis.com/auth/drive.file",
    google_drive_metadata: "https://www.googleapis.com/auth/drive.metadata.readonly",

    # Dropbox scopes
    dropbox_files: "files.metadata.read files.content.read",
    dropbox_files_write: "files.metadata.write files.content.write",

    # OneDrive scopes (Microsoft Graph)
    onedrive_files: "Files.ReadWrite.All offline_access",
    onedrive_files_readonly: "Files.Read.All offline_access"
  }

  @default_scopes %{
    google_drive: :google_drive,
    dropbox: :dropbox_files,
    onedrive: :onedrive_files
  }

  @doc """
  Returns a configured OAuth2 client for the specified service.
  """
  @spec client(atom()) :: Client.t()
  def client(:google_drive) do
    config = get_config(:google_drive)

    Client.new(
      strategy: OAuth2.Strategy.AuthCode,
      client_id: config[:client_id],
      client_secret: config[:client_secret],
      redirect_uri: config[:redirect_uri],
      site: "https://accounts.google.com",
      authorize_url: "/o/oauth2/v2/auth",
      token_url: "/o/oauth2/token"
    )
  end

  def client(:dropbox) do
    config = get_config(:dropbox)

    Client.new(
      strategy: OAuth2.Strategy.AuthCode,
      client_id: config[:client_id],
      client_secret: config[:client_secret],
      redirect_uri: config[:redirect_uri],
      site: "https://www.dropbox.com",
      authorize_url: "/oauth2/authorize",
      token_url: "https://api.dropboxapi.com/oauth2/token"
    )
  end

  def client(:onedrive) do
    config = get_config(:onedrive)
    tenant_id = config[:tenant_id] || "common"

    OAuth2.Client.new(
      strategy: OAuth2.Strategy.AuthCode,
      client_id: config[:client_id],
      client_secret: config[:client_secret],
      redirect_uri: config[:redirect_uri],
      site: "https://login.microsoftonline.com",
      authorize_url: "/#{tenant_id}/oauth2/v2.0/authorize",
      token_url: "/#{tenant_id}/oauth2/v2.0/token"
    )
  end

  @doc """
  Generates an authorization URL for the specified service and scope.
  """
  @spec authorize_url!(atom(), atom() | String.t() | nil) :: String.t() | {:error, String.t()}
  def authorize_url!(service, scope \\ nil)

  def authorize_url!(:google_drive, scope) do
    scope_string = process_scope(scope || @default_scopes.google_drive)

    client = client(:google_drive)

    Client.authorize_url!(
      client,
      scope: scope_string,
      access_type: "offline",
      prompt: "consent",
      include_granted_scopes: "true"
    )
  rescue
    e ->
      Logger.error("Google Drive authorization URL error: #{inspect(e)}")
      {:error, "Failed to generate authorization URL"}
  end

  def authorize_url!(:dropbox, scope) do
    scope_string = process_scope(scope || @default_scopes.dropbox)

    client = client(:dropbox)

    Client.authorize_url!(
      client,
      scope: scope_string,
      token_access_type: "offline"
    )
  rescue
    e ->
      Logger.error("Dropbox authorization URL error: #{inspect(e)}")
      {:error, "Failed to generate authorization URL"}
  end

  def authorize_url!(:onedrive, scope) do
    scope_string = process_scope(scope || @default_scopes.onedrive)
    config = get_config(:onedrive)
    tenant_id = config[:tenant_id] || "common"
    state = "onedrive_auth_#{:rand.uniform(1_000_000)}"

    query_params = %{
      client_id: config[:client_id],
      response_type: "code",
      redirect_uri: config[:redirect_uri],
      scope: scope_string,
      state: state
    }

    "https://login.microsoftonline.com/#{tenant_id}/oauth2/v2.0/authorize?" <>
      URI.encode_query(query_params)
  rescue
    e ->
      Logger.error("OneDrive authorization URL error: #{inspect(e)}")
      {:error, "Failed to generate authorization URL"}
  end

  @doc """
  Exchanges authorization code for access token using a unified approach.
  """

  def get_token(service, code) when service in [:google_drive, :dropbox, :onedrive] do
    execute_token_request(service, code: code)
  end

  @doc """
  Exchanges authorization code for Google Drive access token.
  """

  def google_drive_token(code), do: get_token(:google_drive, code)

  @doc """
  Exchanges authorization code for Dropbox access token.
  """

  def dropbox_token(code), do: get_token(:dropbox, code)

  @doc """
  Exchanges authorization code for OneDrive access token.
  """

  def onedrive_token(code), do: get_token(:onedrive, code)

  @doc """
  Refreshes an access token for any service.
  """

  def refresh_token(service, refresh_token)
      when service in [:google_drive, :dropbox, :onedrive] do
    execute_token_request(service, refresh_token: refresh_token)
  end

  @doc """
  Validates if a token is still valid (not expired).
  """

  def token_valid?(%AccessToken{expires_at: nil}), do: true

  def token_valid?(%AccessToken{expires_at: expires_at}) do
    current_time = System.system_time(:second)
    expires_at > current_time
  end

  @doc """
  Extracts token information in a standardized format.
  """

  def extract_token_info(%AccessToken{} = token) do
    %{
      access_token: token.access_token,
      refresh_token: token.refresh_token,
      expires_at: token.expires_at,
      token_type: token.token_type
    }
  end

  @doc """
  Extracts and validates an access token from token data.
  """

  def get_access_token(_service, %{"access_token" => token})
      when is_binary(token) and token != "" do
    {:ok, String.trim(token)}
  end

  def get_access_token(_service, %{access_token: token}) when is_binary(token) and token != "" do
    {:ok, String.trim(token)}
  end

  def get_access_token(service, _) do
    Logger.error("Invalid or missing access token for #{service}")
    {:error, "Invalid or missing access token"}
  end

  # Private functions

  defp get_config(:google_drive) do
    validate_config(Application.fetch_env!(:wraft_doc, :google_drive), :google_drive)
  end

  defp get_config(:dropbox) do
    validate_config(Application.fetch_env!(:wraft_doc, :dropbox), :dropbox)
  end

  defp get_config(:onedrive) do
    validate_config(Application.fetch_env!(:wraft_doc, :onedrive), :onedrive)
  end

  defp validate_config(config, service) do
    required_keys = [:client_id, :client_secret, :redirect_uri]

    Enum.each(required_keys, fn key ->
      if is_nil(config[key]) or config[key] == "" do
        raise "Missing required configuration for #{service}: #{key}"
      end
    end)

    config
  end

  defp execute_token_request(service, params) do
    with {:ok, client} <- create_client_safely(service),
         {:ok, token_response} <- get_token_safely(client, params) do
      {:ok, parse_token_response(token_response)}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp create_client_safely(service) do
    {:ok, client(service)}
  rescue
    e ->
      Logger.error("Failed to create client for #{service}: #{inspect(e)}")
      {:error, "Client creation failed"}
  end

  defp get_token_safely(client, params) do
    case Client.get_token(client, params) do
      {:ok, %Client{token: %AccessToken{} = token}} ->
        {:ok, token}

      {:ok, %Client{token: token}} ->
        Logger.info("Parsing non-AccessToken response")
        {:ok, token}

      {:error, %OAuth2.Error{reason: reason}} ->
        Logger.error("OAuth2 error: #{inspect(reason)}")
        {:error, "OAuth2 error: #{format_error_reason(reason)}"}

      {:error, %OAuth2.Response{status_code: status, body: body}} ->
        Logger.error("HTTP error: #{status} - #{inspect(body)}")
        {:error, "HTTP error: #{status} - #{format_response_body(body)}"}

      {:error, reason} ->
        Logger.error("Token exchange failed: #{inspect(reason)}")
        {:error, "Token exchange failed: #{format_error_reason(reason)}"}

      other ->
        Logger.warning("Unexpected response format: #{inspect(other)}")
        {:error, "Unexpected response format"}
    end
  end

  defp format_error_reason(reason) when is_binary(reason), do: reason
  defp format_error_reason(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp format_error_reason(reason), do: inspect(reason)

  defp format_response_body(body) when is_binary(body) do
    case String.length(body) do
      len when len > 200 -> String.slice(body, 0, 200) <> "..."
      _ -> body
    end
  end

  defp format_response_body(body), do: inspect(body)

  defp parse_token_response(%AccessToken{access_token: access_token} = token)
       when is_binary(access_token) do
    # Handle case where access_token is a JSON string
    case Jason.decode(access_token) do
      {:ok, parsed_token} ->
        %{
          access_token: parsed_token["access_token"],
          refresh_token: parsed_token["refresh_token"],
          expires_at: calculate_expires_at(parsed_token["expires_in"]),
          token_type: parsed_token["token_type"] || "Bearer",
          scope: parsed_token["scope"]
        }

      {:error, _} ->
        # If it's not JSON, treat as regular token
        %{
          access_token: token.access_token,
          refresh_token: token.refresh_token,
          expires_at: token.expires_at,
          token_type: token.token_type || "Bearer",
          scope: get_in(token.other_params, ["scope"])
        }
    end
  end

  defp parse_token_response(%AccessToken{} = token) do
    %{
      access_token: token.access_token,
      refresh_token: token.refresh_token,
      expires_at: token.expires_at,
      token_type: token.token_type || "Bearer",
      scope: get_in(token.other_params, ["scope"])
    }
  end

  defp parse_token_response(token) when is_map(token) do
    %{
      access_token: token["access_token"],
      refresh_token: token["refresh_token"],
      expires_at: token["expires_at"] || calculate_expires_at(token["expires_in"]),
      token_type: token["token_type"] || "Bearer",
      scope: token["scope"]
    }
  end

  defp calculate_expires_at(nil), do: nil

  defp calculate_expires_at(seconds) when is_integer(seconds) do
    DateTime.utc_now()
    |> DateTime.add(seconds, :second)
    |> DateTime.to_unix()
  end

  defp calculate_expires_at(seconds) when is_binary(seconds) do
    case Integer.parse(seconds) do
      {int_seconds, _} -> calculate_expires_at(int_seconds)
      :error -> nil
    end
  end

  defp process_scope(scope) when is_atom(scope) do
    Map.get(@scopes, scope) ||
      raise "Unknown scope: #{scope}"
  end

  defp process_scope(scope) when is_binary(scope), do: scope

  defp process_scope(scopes) when is_list(scopes) do
    Enum.map_join(scopes, " ", &process_scope/1)
  end

  defp process_scope(_) do
    @scopes[@default_scopes.google_drive]
  end
end
