defmodule WraftDoc.CloudService.CloudAuth do
  @moduledoc """
  Handles Google OAuth2 authentication.
  """
  require Logger
  alias OAuth2.Client

  @scopes %{
    drive: "https://www.googleapis.com/auth/drive",
    drive_readonly: "https://www.googleapis.com/auth/drive.readonly",
    drive_file: "https://www.googleapis.com/auth/drive.file",
    drive_metadata: "https://www.googleapis.com/auth/drive.metadata.readonly"
  }

  def client do
    config = Application.get_env(:wraft_doc, GoogleDrive)

    OAuth2.Client.new(
      strategy: OAuth2.Strategy.AuthCode,
      client_id: config[:client_id],
      client_secret: config[:client_secret],
      redirect_uri: config[:redirect_uri],
      site: "https://accounts.google.com",
      authorize_url: "/o/oauth2/auth",
      token_url: "/o/oauth2/token"
    )
  end

  def authorize_url!(scope \\ :drive) do
    scope_string = process_scope(scope)

    client()
    |> Client.put_param(:access_type, "offline")
    |> Client.put_param(:prompt, "consent")
    |> Client.put_param(:response_type, "code")
    |> Client.put_param(:include_granted_scopes, "true")
    |> Client.put_param(:scope, scope_string)
    |> Client.authorize_url!()
  end

  def get_token(code) do
    config = Application.get_env(:wraft_doc, GoogleDrive)

    token_request =
      client()
      |> Client.put_param(:grant_type, "authorization_code")
      |> Client.put_param(:code, code)
      |> Client.put_param(:redirect_uri, config[:redirect_uri])
      |> Client.put_param(:client_id, config[:client_id])
      |> Client.put_param(:client_secret, config[:client_secret])

    try do
      case Client.get_token(token_request) do
        {:ok, %{token: token}} ->
          # Parse the token if it's a JSON string
          parsed_token = parse_token_response(token)
          {:ok, parsed_token}

        {:error, reason} ->
          {:error, reason}
      end
    rescue
      e -> {:error, "Token exchange failed: #{inspect(e)}"}
    end
  end

  def refresh_token(refresh_token) do
    config = Application.get_env(:wraft_doc, GoogleDrive)

    result =
      client()
      |> Client.put_param(:grant_type, "refresh_token")
      |> Client.put_param(:refresh_token, refresh_token)
      |> Client.put_param(:client_id, config[:client_id])
      |> Client.put_param(:client_secret, config[:client_secret])
      |> Client.get_token()

    case result do
      {:ok, %{token: token}} ->
        {:ok, parse_token_response(token)}

      error ->
        error
    end
  end

  # Parse token when it's returned as a JSON string in access_token field
  defp parse_token_response(%OAuth2.AccessToken{access_token: access_token} = token)
       when is_binary(access_token) do
    # Check if the access_token is a JSON string that needs parsing
    if String.starts_with?(String.trim(access_token), "{") do
      case Jason.decode(access_token) do
        {:ok, decoded} ->
          %{
            access_token: decoded["access_token"],
            refresh_token: decoded["refresh_token"],
            expires_in: decoded["expires_in"],
            token_type: decoded["token_type"],
            scope: decoded["scope"]
          }

        _ ->
          # If parsing fails, return the original structure
          %{
            access_token: access_token,
            refresh_token: token.refresh_token,
            expires_in: nil,
            token_type: token.token_type,
            scope: nil
          }
      end
    else
      # If it's not JSON, return as is
      %{
        access_token: access_token,
        refresh_token: token.refresh_token,
        expires_in: nil,
        token_type: token.token_type,
        scope: nil
      }
    end
  end

  # Fallback for any other token format
  defp parse_token_response(token) do
    %{
      access_token: token.access_token,
      refresh_token: token.refresh_token,
      expires_in: nil,
      token_type: token.token_type,
      scope: nil
    }
  end

  defp process_scope(scope) when is_atom(scope) do
    Map.get(@scopes, scope, @scopes.drive)
  end

  defp process_scope(scope) when is_binary(scope), do: scope

  defp process_scope(scopes) when is_list(scopes) do
    Enum.map_join(scopes, " ", fn
      scope when is_atom(scope) -> Map.get(@scopes, scope, @scopes.drive)
      scope when is_binary(scope) -> scope
    end)
  end
end
