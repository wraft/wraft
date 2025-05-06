# defmodule WraftDoc.CloudAuth do
#   @moduledoc """
#   OAuth2 authentication module for Google Drive integration.
#   Handles authorization, token acquisition, and token refreshing.
#   """
#   use OAuth2.Strategy

#   def client do
#     OAuth2.Client.new([
#       strategy: __MODULE__,
#       client_id: System.get_env("GOOGLE_CLIENT_ID"),
#       client_secret: System.get_env("GOOGLE_CLIENT_SECRET"),
#       site: "https://accounts.google.com",
#       authorize_url: "https://accounts.google.com/o/oauth2/v2/auth",
#       token_url: "https://oauth2.googleapis.com/token",
#       redirect_uri: System.get_env("GOOGLE_REDIRECT_URI") || "http://localhost:4000/oauth/callback/google_drive"
#     ])
#     |> OAuth2.Client.put_serializer("application/json", Jason)
#   end

#   @doc """
#   Generate the authorization URL for Google OAuth2 flow.
#   """
#   def authorize_url!(params \\ []) do
#     client()
#     |> OAuth2.Client.authorize_url!(Keyword.merge([
#       access_type: "offline",  # Get a refresh token
#       prompt: "consent",       # Always show consent screen
#       scope: "https://www.googleapis.com/auth/drive.file https://www.googleapis.com/auth/drive.readonly"
#     ], params))
#   end

#   @doc """
#   Exchange authorization code for access token.
#   """
#   def get_token!(params \\ %{}) do
#     client()
#     |> OAuth2.Client.get_token!(Map.merge(params, %{
#       grant_type: "authorization_code",
#       redirect_uri: client().redirect_uri
#     }))
#   end

#   @doc """
#   Refresh an expired access token using a refresh token.
#   """
#   def refresh_token!(refresh_token) do
#     try do
#       client()
#       |> OAuth2.Client.get_token!(%{
#         grant_type: "refresh_token",
#         refresh_token: refresh_token
#       })
#     rescue
#       e ->
#         require Logger
#         Logger.error("Failed to refresh token: #{inspect(e)}")
#         {:error, "Failed to refresh token"}
#     end
#   end
# end
