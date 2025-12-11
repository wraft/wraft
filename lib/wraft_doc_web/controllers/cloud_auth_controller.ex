defmodule WraftDocWeb.Api.V1.CloudImportAuthController do
  @moduledoc """
  Controller for handling cloud provider interactions with Google Drive, Dropbox, and OneDrive.
  Provides endpoints for authentication, file exploration, and file operations.
  Now using Assent for OAuth2 authentication.
  """

  use WraftDocWeb, :controller
  use OpenApiSpex.ControllerSpecs

  plug WraftDocWeb.Plug.AddActionLog
  plug WraftDocWeb.Plug.FeatureFlagCheck, feature: :repository

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.CloudImport.CloudAuth
  alias WraftDoc.CloudImport.StateStore
  alias WraftDocWeb.Schemas.CloudAuth, as: CloudAuthSchema

  require Logger

  @providers ["google_drive", "dropbox", "onedrive"]

  tags(["Authentication"])

  operation(:login_url,
    summary: "Generate OAuth login URL",
    description: """
    Generates a redirect URL for OAuth authentication with the specified provider.
    Stores OAuth session parameters for later verification during the callback phase.
    """,
    operation_id: "generateOAuthRedirectUrl",
    parameters: [
      provider: [
        in: :path,
        type: :string,
        description: "Provider to authenticate with (google_drive, dropbox, onedrive)",
        required: true
      ]
    ],
    responses: [
      ok: {"OK", "application/json", CloudAuthSchema.AuthLoginUrlResponse},
      bad_request: {"Bad Request", "application/json", CloudAuthSchema.ErrorResponse}
    ]
  )

  @doc """
  Generates OAuth login URL for the specified provider.

  ## Parameters
  - provider: The provider to authenticate with (e.g., "google_drive", "dropbox", "onedrive")

  ## Responses
  - 200: Returns redirect URL for OAuth flow
    ```json
    {
      "status": "success",
      "redirect_url": "https://accounts.google.com/o/oauth2/auth?..."
    }
    ```
  - 400: Invalid provider parameter
    ```json
    {
      "error": "Invalid provider specified",
      "details": "Supported providers: google_drive, dropbox, onedrive"
    }
    ```
  - 403: Unauthorized request
  """
  @spec login_url(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def login_url(conn, %{"provider" => provider})
      when provider in @providers do
    current_user = conn.assigns[:current_user]
    provider = String.to_existing_atom(provider)

    with {:ok, redirect_url, session_params} <-
           CloudAuth.authorize_url!(
             provider,
             current_user.current_org_id
           ) do
      StateStore.put(current_user.id, provider, session_params)

      json(conn, %{
        status: "success",
        redirect_url: redirect_url
      })
    end
  end

  def login_url(_conn, _params), do: {:error, "Invalid provider"}

  operation(:google_callback,
    summary: "Google Drive OAuth callback endpoint",
    description: """
    **Internal OAuth callback endpoint - automatically called by Google OAuth servers.**

    This endpoint is not intended for direct developer use. It is automatically invoked by Google's
    OAuth servers after a user completes the authorization process. The endpoint:

    - Receives the authorization code from Google
    - Exchanges it for access tokens
    - Stores the tokens for future API calls
    - Redirects the user back to the frontend application

    Developers should use the `/auth/google_drive` endpoint to initiate the OAuth flow.
    """,
    operation_id: "handleGoogleOAuthCallback",
    tags: ["OAuth Callbacks"],
    parameters: [
      code: [
        in: :query,
        type: :string,
        description: "Authorization code from Google OAuth servers",
        required: true
      ],
      state: [
        in: :query,
        type: :string,
        description: "OAuth state parameter for CSRF protection",
        required: false
      ]
    ],
    responses: [
      found: {"Found - Redirect to frontend", "text/html", CloudAuthSchema.OAuthCallbackResponse},
      bad_request: {"Bad Request", "application/json", CloudAuthSchema.ErrorResponse},
      forbidden: {"Unauthorized", "application/json", CloudAuthSchema.ErrorResponse}
    ]
  )

  @doc """
  Handles Google Drive OAuth callback.

  This function is automatically called by Google's OAuth servers after user authorization.
  It processes the authorization code and redirects the user back to the frontend.
  """
  @spec google_callback(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def google_callback(conn, params) do
    conn.assigns[:current_user]
    |> CloudAuth.handle_oauth_callback(params, :google_drive)
    |> then(&redirect(conn, to: &1))
  end

  operation(:dropbox_callback,
    summary: "Dropbox OAuth callback endpoint",
    description: """
    **Internal OAuth callback endpoint - automatically called by Dropbox OAuth servers.**

    This endpoint is not intended for direct developer use. It is automatically invoked by Dropbox's
    OAuth servers after a user completes the authorization process. The endpoint:

    - Receives the authorization code from Dropbox
    - Exchanges it for access tokens
    - Stores the tokens for future API calls
    - Redirects the user back to the frontend application

    Developers should use the `/auth/dropbox` endpoint to initiate the OAuth flow.
    """,
    operation_id: "handleDropboxOAuthCallback",
    tags: ["OAuth Callbacks"],
    parameters: [
      code: [
        in: :query,
        type: :string,
        description: "Authorization code from Dropbox OAuth servers",
        required: true
      ],
      state: [
        in: :query,
        type: :string,
        description: "OAuth state parameter for CSRF protection",
        required: false
      ],
      error: [
        in: :query,
        type: :string,
        description: "Error code if authorization was denied",
        required: false
      ],
      error_description: [
        in: :query,
        type: :string,
        description: "Human-readable error description",
        required: false
      ]
    ],
    responses: [
      found: {"Found - Redirect to frontend", "text/html", CloudAuthSchema.OAuthCallbackResponse},
      bad_request: {"Bad Request", "application/json", CloudAuthSchema.ErrorResponse},
      unauthorized: {"Unauthorized", "application/json", CloudAuthSchema.ErrorResponse}
    ]
  )

  @doc """
  Handles Dropbox OAuth callback.

  This function is automatically called by Dropbox's OAuth servers after user authorization.
  It processes the authorization code and redirects the user back to the frontend.
  """
  @spec dropbox_callback(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def dropbox_callback(conn, params) do
    conn.assigns[:current_user]
    |> CloudAuth.handle_oauth_callback(params, :dropbox)
    |> then(&redirect(conn, to: &1))
  end

  operation(:onedrive_callback,
    summary: "OneDrive OAuth callback endpoint",
    description: """
    **Internal OAuth callback endpoint - automatically called by Microsoft OAuth servers.**

    This endpoint is not intended for direct developer use. It is automatically invoked by Microsoft's
    OAuth servers after a user completes the authorization process. The endpoint:

    - Receives the authorization code from Microsoft
    - Exchanges it for access tokens
    - Stores the tokens for future API calls
    - Redirects the user back to the frontend application

    Developers should use the `/auth/onedrive` endpoint to initiate the OAuth flow.
    """,
    operation_id: "handleOneDriveOAuthCallback",
    tags: ["OAuth Callbacks"],
    parameters: [
      code: [
        in: :query,
        type: :string,
        description: "Authorization code from Microsoft OAuth servers",
        required: true
      ],
      state: [
        in: :query,
        type: :string,
        description: "OAuth state parameter for CSRF protection",
        required: false
      ]
    ],
    responses: [
      found: {"Found - Redirect to frontend", "text/html", CloudAuthSchema.OAuthCallbackResponse},
      bad_request: {"Bad Request", "application/json", CloudAuthSchema.ErrorResponse},
      forbidden: {"Unauthorized", "application/json", CloudAuthSchema.ErrorResponse}
    ]
  )

  @doc """
  Handles OneDrive OAuth callback.

  This function is automatically called by Microsoft's OAuth servers after user authorization.
  It processes the authorization code and redirects the user back to the frontend.
  """
  @spec onedrive_callback(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def onedrive_callback(conn, params) do
    conn.assigns[:current_user]
    |> CloudAuth.handle_oauth_callback(params, :onedrive)
    |> then(&redirect(conn, to: &1))
  end
end
