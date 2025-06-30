defmodule WraftDoc.CloudImport.CloudAuth do
  @moduledoc """
  Handles OAuth2 authentication for Google Drive, Dropbox, and OneDrive using Assent.

  Provides functions for:
  - Generating authorization URLs
  - Exchanging authorization codes for tokens
  - Refreshing access tokens
  """

  require Logger

  alias Assent.Strategy.Google
  alias Assent.Strategy.OAuth2
  alias WraftDoc.CloudImport.RepositoryCloudTokens, as: AuthTokens
  alias WraftDoc.CloudImport.StateStore

  @scopes %{
    # Google Drive scopes
    google_drive: ["https://www.googleapis.com/auth/drive"],
    google_drive_readonly: ["https://www.googleapis.com/auth/drive.readonly"],
    google_drive_file: ["https://www.googleapis.com/auth/drive.file"],
    google_drive_metadata: ["https://www.googleapis.com/auth/drive.metadata.readonly"],

    # Dropbox scopes
    dropbox_files: ["files.metadata.read", "files.content.read"],
    dropbox_files_write: ["files.metadata.write", "files.content.write"],

    # OneDrive scopes
    onedrive_files: ["Files.ReadWrite.All", "offline_access"],
    onedrive_files_readonly: ["Files.Read.All", "offline_access"]
  }

  @default_scopes %{
    google_drive: :google_drive,
    dropbox: :dropbox_files,
    onedrive: :onedrive_files
  }

  @doc """
  Generates an authorization URL for the specified provider.
  """
  @spec authorize_url!(atom(), atom() | nil) :: {:ok, String.t()} | {:error, String.t()}
  def authorize_url!(provider, scope \\ nil)

  def authorize_url!(:google_drive, scope) do
    scope
    |> get_google_config()
    |> Google.authorize_url()
    |> case do
      {:ok, %{url: url, session_params: session_params}} ->
        {:ok, url, session_params}

      {:error, error} ->
        Logger.error("Google Drive authorization URL error: #{inspect(error)}")
        {:error, "Failed to generate Google Drive authorization URL #{inspect(error)}"}
    end
  end

  # TODO: Uncomment and implement Dropbox authorization URL generation when Dropbox integration is enabled

  # def authorize_url!(:dropbox, scope) do
  #   config = get_dropbox_config(scope)

  #   case OAuth2.authorize_url(config) do
  #     {:ok, %{url: url}} ->
  #       {:ok, url}

  #     {:error, error} ->
  #       Logger.error("Dropbox authorization URL error: #{inspect(error)}")
  #       {:error, "Failed to generate Dropbox authorization URL"}
  #   end
  # end

  # def authorize_url!(:onedrive, scope) do
  #   config = get_onedrive_config(scope)

  #   case OAuth2.authorize_url(config) do
  #     {:ok, %{url: url}} ->
  #       {:ok, url}

  #     {:error, error} ->
  #       Logger.error("OneDrive authorization URL error: #{inspect(error)}")
  #       {:error, "Failed to generate OneDrive authorization URL"}
  #   end
  # end

  @doc """
  Exchanges authorization code for access token.
  """
  @spec get_token(atom(), String.t(), String.t()) ::
          {:ok, map(), String.t()} | {:error, String.t()}
  def get_token(:google_drive, user_id, code) do
    {:ok, session_params} = StateStore.get(user_id, :google_drive)
    config = Keyword.put(get_google_config(), :session_params, session_params)

    case OAuth2.callback(config, %{"code" => code, "state" => session_params.state}, Google) do
      {:ok, %{user: user, token: token}} ->
        {:ok, user, token}

      {:error, error} ->
        Logger.error("Google Drive token exchange error: #{inspect(error)}")
        {:error, "Failed to exchange Google Drive authorization code"}
    end
  end

  # TODO: Uncomment and implement Dropbox authorization URL generation when Dropbox integration is enabled
  # def get_token(:dropbox, code, _state) do
  #   config = get_dropbox_config()

  #   case OAuth2.callback(config, %{"code" => code}) do
  #     {:ok, %{user: _user, token: token}} ->
  #       {:ok, normalize_token(token)}

  #     {:error, error} ->
  #       Logger.error("Dropbox token exchange error: #{inspect(error)}")
  #       {:error, "Failed to exchange Dropbox authorization code"}
  #   end
  # end

  # def get_token(:onedrive, code, _state) do
  #   config = get_onedrive_config()

  #   case OAuth2.callback(config, %{"code" => code}) do
  #     {:ok, %{user: _user, token: token}} ->
  #       {:ok, normalize_token(token)}

  #     {:error, error} ->
  #       Logger.error("OneDrive token exchange error: #{inspect(error)}")
  #       {:error, "Failed to exchange OneDrive authorization code"}
  #   end
  # end

  @doc """
  Refreshes an access token for any provider.
  """
  @spec refresh_token(atom(), String.t()) :: {:ok, map()} | {:error, String.t()}
  def refresh_token(:google_drive, refresh_token) do
    get_google_config()
    |> OAuth2.refresh_access_token(%{"refresh_token" => refresh_token})
    |> case do
      {:ok, token} ->
        {:ok, normalize_token(token)}

      {:error, error} ->
        Logger.error("Google Drive token refresh error: #{inspect(error)}")
        {:error, "Failed to refresh Google Drive token"}
    end
  end

  # TODO: Uncomment and implement Dropbox authorization URL generation when Dropbox integration is enabled
  # def refresh_token(:dropbox, refresh_token) do
  #   config = get_dropbox_config()

  #   case OAuth2.refresh_access_token(config, %{"refresh_token" => refresh_token}) do
  #     {:ok, token} ->
  #       {:ok, normalize_token(token)}

  #     {:error, error} ->
  #       Logger.error("Dropbox token refresh error: #{inspect(error)}")
  #       {:error, "Failed to refresh Dropbox token"}
  #   end
  # end

  # def refresh_token(:onedrive, refresh_token) do
  #   config = get_onedrive_config()

  #   case OAuth2.refresh_access_token(config, %{"refresh_token" => refresh_token}) do
  #     {:ok, token} ->
  #       {:ok, normalize_token(token)}

  #     {:error, error} ->
  #       Logger.error("OneDrive token refresh error: #{inspect(error)}")
  #       {:error, "Failed to refresh OneDrive token"}
  #   end
  # end

  @doc """
  Validates if a token is still valid (not expired).
  """
  @spec token_valid?(map()) :: boolean()
  def token_valid?(%{"expires_at" => nil}), do: true

  def token_valid?(%{"expires_at" => expires_at}) when is_integer(expires_at) do
    current_time = System.system_time(:second)
    expires_at > current_time
  end

  def token_valid?(_), do: false

  defp get_google_config(scope \\ nil) do
    config = get_base_config(:google_drive)
    scopes = get_scopes(:google_drive, scope)

    config
    |> Keyword.put(:scope, Enum.join(scopes, " "))
    |> Keyword.put(:base_url, "https://accounts.google.com")
    |> Keyword.put(:authorize_url, "/o/oauth2/v2/auth")
    |> Keyword.put(:token_url, "https://oauth2.googleapis.com/token")
    |> Keyword.put(:issuer, "https://accounts.google.com")
    |> Keyword.put(:authorization_params,
      access_type: "offline",
      prompt: "consent",
      scope: "https://www.googleapis.com/auth/drive"
    )
    |> Keyword.put(:user_url, "https://openidconnect.googleapis.com/v1/userinfo")
    |> Keyword.put(:auth_method, :client_secret_post)
  end

  # TODO: Uncomment and implement Dropbox authorization URL generation when Dropbox integration is enabled
  # defp get_dropbox_config(scope \\ nil) do
  #   config = get_base_config(:dropbox)
  #   scopes = get_scopes(:dropbox, scope)

  #   config
  #   |> Keyword.put(:scope, Enum.join(scopes, " "))
  #   |> Keyword.put(:strategy, OAuth2)
  #   |> Keyword.put(:base_url, "https://www.dropbox.com")
  #   |> Keyword.put(:authorize_url, "/oauth2/authorize")
  #   |> Keyword.put(:token_url, "https://api.dropboxapi.com/oauth2/token")
  #   |> Keyword.put(:authorization_params, token_access_type: "offline")
  # end

  # defp get_onedrive_config(scope \\ nil) do
  #   config = get_base_config(:onedrive)
  #   scopes = get_scopes(:onedrive, scope)
  #   tenant_id = config[:tenant_id] || "common"

  #   config
  #   |> Keyword.put(:scope, Enum.join(scopes, " "))
  #   |> Keyword.put(:strategy, OAuth2)
  #   |> Keyword.put(:base_url, "https://login.microsoftonline.com")
  #   |> Keyword.put(:authorize_url, "/#{tenant_id}/oauth2/v2.0/authorize")
  #   |> Keyword.put(:token_url, "/#{tenant_id}/oauth2/v2.0/token")
  # end

  defp get_base_config(provider) do
    app_config = Application.fetch_env!(:wraft_doc, provider)
    validate_config!(app_config, provider)

    [
      client_id: app_config[:client_id],
      client_secret: app_config[:client_secret],
      redirect_uri: app_config[:redirect_uri]
    ]
  end

  defp get_scopes(provider, scope_key) do
    scope_key = scope_key || @default_scopes[provider]
    @scopes[scope_key] || @scopes[@default_scopes[provider]]
  end

  defp validate_config!(config, provider) do
    required_keys = [:client_id, :client_secret, :redirect_uri]

    Enum.each(required_keys, fn key ->
      if is_nil(config[key]) or config[key] == "" do
        raise "Missing required configuration for #{provider}: #{key}"
      end
    end)
  end

  defp normalize_token(
         %{
           "access_token" => access_token,
           "refresh_token" => refresh_token,
           "expires_in" => expires_in
         } = token
       ) do
    %{
      "access_token" => access_token,
      "refresh_token" => refresh_token,
      "expires_at" => calculate_expires_at(expires_in),
      "token_type" => Map.get(token, "token_type", "Bearer"),
      "scope" => Map.get(token, "scope")
    }
  end

  defp normalize_token(token) when is_map(token) do
    %{
      "access_token" => token["access_token"],
      "refresh_token" => token["refresh_token"],
      "expires_at" => token["expires_at"] || calculate_expires_at(token["expires_in"]),
      "token_type" => token["token_type"] || "Bearer",
      "scope" => token["scope"]
    }
  end

  defp calculate_expires_at(nil), do: nil

  defp calculate_expires_at(seconds) when is_integer(seconds) do
    DateTime.utc_now()
    |> DateTime.add(seconds, :second)
    |> DateTime.to_unix()
  end

  defp calculate_expires_at(seconds) when is_binary(seconds) do
    seconds
    |> Integer.parse()
    |> case do
      {int_seconds, _} -> calculate_expires_at(int_seconds)
      :error -> nil
    end
  end

  @doc """
  Handles auth callback.
  """
  @spec handle_oauth_callback(User.t(), map(), atom(), String.t()) :: String.t()
  def handle_oauth_callback(
        user,
        params,
        provider,
        code
      ) do
    with {:ok, user_data, token_data} <-
           get_token(provider, user.id, code),
         {:ok, _token} <-
           AuthTokens.save_token_data(user, token_data, provider, user_data) do
      Logger.info("Successfully authenticated with #{token_data["access_token"]}")
      get_redirect_path(params)
    else
      {:error, reason} ->
        Logger.error(
          "#{format_provider_name(provider)} authentication failed for user #{user.id}: #{inspect(reason)}"
        )

        get_redirect_path(params, "/")
    end
  end

  defp get_redirect_path(params, default \\ "/") do
    case params do
      %{"redirect_to" => path} when is_binary(path) and path != "" ->
        path

      %{"state" => state} when is_binary(state) ->
        extract_redirect_from_state(state, default)

      _ ->
        default
    end
  end

  defp extract_redirect_from_state(state, default) do
    state
    |> String.split("_", parts: 4)
    |> case do
      [_provider, "auth", _random, redirect_path] when redirect_path != "" ->
        "/" <> redirect_path

      _ ->
        default
    end
  end

  defp format_provider_name(:google_drive), do: "Google Drive"
  defp format_provider_name(:dropbox), do: "Dropbox"
  defp format_provider_name(:onedrive), do: "OneDrive"
  defp format_provider_name(provider), do: provider |> to_string() |> String.capitalize()
end
