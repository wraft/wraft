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
  alias WraftDoc.CloudImport.StateStore
  alias WraftDoc.CloudImport.Token.Manager, as: TokenManager
  alias WraftDoc.Integrations
  alias WraftDoc.Integrations.Integration

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
  def authorize_url!(provider, _organisation_id, scope \\ nil)

  def authorize_url!(:google_drive, organisation_id, scope) do
    organisation_id
    |> get_google_config(scope)
    |> case do
      {:error, reason} ->
        {:error, reason}

      config ->
        case Google.authorize_url(config) do
          {:ok, %{url: url, session_params: session_params}} ->
            {:ok, url, session_params}

          {:error, error} ->
            {:error, "Failed to generate Google Drive authorization URL: #{inspect(error)}"}
        end
    end
  end

  # TODO: Uncomment and implement Dropbox authorization URL generation when Dropbox integration is enabled

  # def authorize_url!(:dropbox, scope) do
  #   config = get_dropbox_config(scope)

  #   case OAuth2.authorize_url(config) do
  #     {:ok, %{url: url}} ->
  #       {:ok, url}

  #     {:error, error} ->
  #       {:error, "Failed to generate Dropbox authorization URL"}
  #   end
  # end

  # def authorize_url!(:onedrive, scope) do
  #   config = get_onedrive_config(scope)

  #   case OAuth2.authorize_url(config) do
  #     {:ok, %{url: url}} ->
  #       {:ok, url}

  #     {:error, error} ->
  #       {:error, "Failed to generate OneDrive authorization URL"}
  #   end
  # end

  @doc """
  Exchanges authorization code for access token.
  """
  @spec get_token(atom(), User.t(), String.t()) ::
          {:ok, map(), String.t()} | {:error, String.t()}
  def get_token(:google_drive, %{current_org_id: organisation_id} = user, code) do
    {:ok, session_params} = StateStore.get(user.id, :google_drive)

    organisation_id
    |> get_google_config()
    |> Keyword.put(:session_params, session_params)
    |> OAuth2.callback(%{"code" => code, "state" => session_params.state}, Google)
    |> case do
      {:ok,
       %{
         user: google_user,
         token:
           %{
             "refresh_token" => refresh_token,
             "expires_in" => access_token_expires_in,
             "refresh_token_expires_in" => refresh_token_expires_in
           } = token
       }} ->
        TokenManager.start(
          organisation_id,
          refresh_token
        )

        now = DateTime.utc_now()

        access_token_expires_at = DateTime.add(now, access_token_expires_in, :second)
        refresh_token_expires_at = DateTime.add(now, refresh_token_expires_in, :second)

        {:ok, google_user,
         Map.merge(token, %{
           "updated_at" => now,
           "access_token_expires_at" => access_token_expires_at,
           "refresh_token_expires_at" => refresh_token_expires_at
         })}

      {:error, _error} ->
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
  #       {:error, "Failed to exchange OneDrive authorization code"}
  #   end
  # end

  @doc """
  Refreshes an access token for any provider.
  """
  @spec refresh_token(atom(), String.t(), String.t()) :: {:ok, map()} | {:error, String.t()}
  def refresh_token(:google_drive, organisation_id, refresh_token) do
    with integration <- Integrations.get_integration_by_provider(organisation_id, "google_drive"),
         {:ok, token} <-
           organisation_id
           |> get_google_config()
           |> OAuth2.refresh_access_token(%{"refresh_token" => refresh_token}),
         normalized <- normalize_token(token),
         {:ok, _updated} <- update_integration_metadata(integration, normalized) do
      {:ok, normalized}
    else
      nil ->
        {:error, "Integration not found"}

      {:error, _reason} ->
        {:error, "Failed to refresh Google Drive token"}
    end
  end

  defp update_integration_metadata(
         %Integration{} = integration,
         %{"access_token" => at, "expires_in" => expires_in}
       ) do
    updated_metadata =
      Map.merge(integration.metadata || %{}, %{
        "access_token" => at,
        "expires_in" => expires_in
      })

    Integrations.update_metadata(integration, updated_metadata)
  end

  # TODO: Uncomment and implement Dropbox authorization URL generation when Dropbox integration is enabled
  # def refresh_token(:dropbox, refresh_token) do
  #   config = get_dropbox_config()

  #   case OAuth2.refresh_access_token(config, %{"refresh_token" => refresh_token}) do
  #     {:ok, token} ->
  #       {:ok, normalize_token(token)}

  #     {:error, error} ->
  #       {:error, "Failed to refresh Dropbox token"}
  #   end
  # end

  # def refresh_token(:onedrive, refresh_token) do
  #   config = get_onedrive_config()

  #   case OAuth2.refresh_access_token(config, %{"refresh_token" => refresh_token}) do
  #     {:ok, token} ->
  #       {:ok, normalize_token(token)}

  #     {:error, error} ->
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

  defp get_google_config(organisation_id, scope \\ nil) do
    scopes = get_scopes(:google_drive, scope)

    case get_base_config("google_drive", organisation_id) do
      {:ok, config} ->
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

      {:error, reason} ->
        {:error, reason}
    end
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

  defp get_base_config(provider, organisation_id) do
    case Integrations.get_integration_by_provider(organisation_id, provider) do
      nil ->
        {:error, "No integration found for #{provider}"}

      %{config: config} ->
        app_config =
          config
          |> Map.to_list()
          |> Enum.map(fn {k, v} -> {safe_to_atom(k), v} end)

        case validate_config(app_config, provider) do
          :ok ->
            {:ok,
             [
               client_id: app_config[:client_id],
               client_secret: app_config[:client_secret],
               redirect_uri: app_config[:redirect_uri]
             ]}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  defp safe_to_atom(key) when is_binary(key) do
    String.to_existing_atom(key)
  rescue
    ArgumentError -> String.to_atom(key)
  end

  defp validate_config(config, provider) do
    required_keys = [:client_id, :client_secret, :redirect_uri]

    case Enum.find(required_keys, fn key -> is_nil(config[key]) or config[key] == "" end) do
      nil -> :ok
      missing -> {:error, "Missing required configuration for #{provider}: #{missing}"}
    end
  end

  defp get_scopes(provider, scope_key) do
    scope_key = scope_key || @default_scopes[provider]
    @scopes[scope_key] || @scopes[@default_scopes[provider]]
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
      "expires_in" => expires_in,
      "token_type" => Map.get(token, "token_type", "Bearer"),
      "scope" => Map.get(token, "scope")
    }
  end

  defp normalize_token(token) when is_map(token) do
    %{
      "access_token" => token["access_token"],
      "refresh_token" => token["refresh_token"],
      "expires_in" => token["expires_in"],
      "token_type" => token["token_type"] || "Bearer",
      "scope" => token["scope"]
    }
  end

  @doc """
  Handles auth callback.
  """
  @spec handle_oauth_callback(User.t(), map(), atom()) :: String.t()
  def handle_oauth_callback(
        %{id: _user_id, current_org_id: org_id} = user,
        %{"code" => code} = params,
        provider
      ) do
    with {:ok, _user_data, token_data} <-
           get_token(provider, user, code),
         integration <-
           Integrations.get_integration_by_provider(org_id, "google_drive"),
         {:ok, _token} <-
           Integrations.update_integration(integration, %{
             "metadata" => Map.merge(integration.metadata || %{}, token_data)
           }) do
      get_redirect_path(params)
    else
      {:error, _reason} ->
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
end
