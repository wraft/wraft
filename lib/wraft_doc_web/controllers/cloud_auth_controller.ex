defmodule WraftDocWeb.Api.V1.CloudImportAuthController do
  @moduledoc """
  Controller for handling cloud provider interactions with Google Drive, Dropbox, and OneDrive.
  Provides endpoints for authentication, file exploration, and file operations.
  Now using Assent for OAuth2 authentication.
  """

  use WraftDocWeb, :controller
  use PhoenixSwagger

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.CloudImport.CloudAuth
  alias WraftDoc.CloudImport.StateStore

  require Logger

  @providers [:google_drive, :dropbox, :onedrive]

  def swagger_definitions do
    %{
      AuthLoginUrlRequest:
        swagger_schema do
          title("Auth Login URL Request")
          description("Request parameters for generating OAuth login URL")

          properties do
            provider(:string, "Provider to authenticate with",
              required: true,
              enum: Enum.map(@providers, &Atom.to_string/1)
            )
          end

          example(%{
            "provider" => "google_drive"
          })
        end,
      AuthLoginUrlResponse:
        swagger_schema do
          title("Auth Login URL Response")
          description("Successful response containing OAuth redirect URL")

          properties do
            status(:string, "Status of the request", example: "success")
            redirect_url(:string, "URL to redirect for OAuth authentication")
          end

          example(%{
            "status" => "success",
            "redirect_url" =>
              "https://accounts.google.com/o/oauth2/auth?response_type=code&client_id=12345&redirect_uri=https%3A%2F%2Fyourapp.com%2Fauth%2Fcallback&scope=email%20profile&state=abc123"
          })
        end,
      OAuthCallbackResponse:
        swagger_schema do
          title("OAuth Callback Response")
          description("Response from OAuth callback - redirects to frontend")

          properties do
            message(:string, "Informational message about the redirect")
            redirect_location(:string, "Frontend URL where user will be redirected")
          end

          example(%{
            "message" => "Redirecting to frontend application",
            "redirect_location" => "https://yourapp.com/dashboard?auth=success"
          })
        end,
      ErrorResponse:
        swagger_schema do
          title("Error Response")
          description("Standard error response format")

          properties do
            error(:string, "Error message")
            details(:string, "Additional error details", required: false)
          end

          example(%{
            "error" => "Invalid provider specified",
            "details" => "Supported providers: google_drive, dropbox, onedrive"
          })
        end
    }
  end

  swagger_path :login_url do
    get("/auth/{provider}")
    summary("Generate OAuth login URL")

    description("""
    Generates a redirect URL for OAuth authentication with the specified provider.
    Stores OAuth session parameters for later verification during the callback phase.
    """)

    operation_id("generateOAuthRedirectUrl")
    produces("application/json")
    tag("Authentication")

    parameters do
      provider(:path, :string, "Provider to authenticate with",
        required: true,
        enum: Enum.map(@providers, &Atom.to_string/1),
        example: "google_drive"
      )
    end

    response(200, "OK", Schema.ref(:AuthLoginUrlResponse),
      example: %{
        "status" => "success",
        "redirect_url" =>
          "https://accounts.google.com/o/oauth2/auth?response_type=code&client_id=12345&redirect_uri=https%3A%2F%2Fyourapp.com%2Fauth%2Fcallback&scope=email%20profile&state=abc123"
      }
    )

    response(400, "Bad Request", Schema.ref(:ErrorResponse),
      example: %{
        "error" => "Invalid provider specified",
        "details" => "Supported providers: google_drive, dropbox, onedrive"
      }
    )
  end

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
  - 401: Unauthorized request
  """
  @spec login_url(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def login_url(conn, %{"provider" => provider}) do
    user = conn.assigns[:current_user]

    with provider <- String.to_existing_atom(provider),
         true <- provider in @providers,
         {:ok, redirect_url, session_params} <-
           CloudAuth.authorize_url!(provider, user.current_org_id) do
      StateStore.put(user.id, provider, session_params)

      Logger.info("Redirecting to #{provider} OAuth: #{redirect_url}")

      json(conn, %{
        status: "success",
        redirect_url: redirect_url
      })
    end
  end

  swagger_path :google_callback do
    get("/auth/google/callback")
    # TODO callback variable
    summary("Google Drive OAuth callback endpoint")

    description("""
    **Internal OAuth callback endpoint - automatically called by Google OAuth servers.**

    This endpoint is not intended for direct developer use. It is automatically invoked by Google's
    OAuth servers after a user completes the authorization process. The endpoint:

    - Receives the authorization code from Google
    - Exchanges it for access tokens
    - Stores the tokens for future API calls
    - Redirects the user back to the frontend application

    Developers should use the `/auth/google_drive` endpoint to initiate the OAuth flow.
    """)

    operation_id("handleGoogleOAuthCallback")
    produces("text/html")
    tag("OAuth Callbacks")

    parameters do
      code(:query, :string, "Authorization code from Google OAuth servers",
        required: true,
        description: "Temporary code provided by Google after user authorization"
      )

      state(:query, :string, "OAuth state parameter for CSRF protection",
        required: false,
        description: "State value originally sent to Google for security verification"
      )

      error(:query, :string, "Error code if authorization was denied",
        required: false,
        description: "Present only when user denies authorization or an error occurs"
      )

      error_description(:query, :string, "Human-readable error description",
        required: false,
        description: "Additional details about the error if present"
      )
    end

    response(302, "Found - Redirect to frontend", Schema.ref(:OAuthCallbackResponse),
      description:
        "Successful OAuth callback - redirects user to frontend application with auth status"
    )

    response(400, "Bad Request", Schema.ref(:ErrorResponse),
      description: "Invalid authorization code or missing required parameters"
    )

    response(401, "Unauthorized", Schema.ref(:ErrorResponse),
      description: "OAuth state mismatch or invalid session"
    )
  end

  @doc """
  Handles Google Drive OAuth callback.

  This function is automatically called by Google's OAuth servers after user authorization.
  It processes the authorization code and redirects the user back to the frontend.
  """
  @spec google_callback(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def google_callback(conn, %{"code" => code} = params) do
    conn.assigns[:current_user]
    |> CloudAuth.handle_oauth_callback(params, :google_drive, code)
    |> then(&redirect(conn, to: &1))
  end

  swagger_path :dropbox_callback do
    get("/auth/dropbox/callback")
    summary("Dropbox OAuth callback endpoint")

    description("""
    **Internal OAuth callback endpoint - automatically called by Dropbox OAuth servers.**

    This endpoint is not intended for direct developer use. It is automatically invoked by Dropbox's
    OAuth servers after a user completes the authorization process. The endpoint:

    - Receives the authorization code from Dropbox
    - Exchanges it for access tokens
    - Stores the tokens for future API calls
    - Redirects the user back to the frontend application

    Developers should use the `/auth/dropbox` endpoint to initiate the OAuth flow.
    """)

    operation_id("handleDropboxOAuthCallback")
    produces("text/html")
    tag("OAuth Callbacks")

    parameters do
      code(:query, :string, "Authorization code from Dropbox OAuth servers",
        required: true,
        description: "Temporary code provided by Dropbox after user authorization"
      )

      state(:query, :string, "OAuth state parameter for CSRF protection",
        required: false,
        description: "State value originally sent to Dropbox for security verification"
      )

      error(:query, :string, "Error code if authorization was denied",
        required: false,
        description: "Present only when user denies authorization or an error occurs"
      )

      error_description(:query, :string, "Human-readable error description",
        required: false,
        description: "Additional details about the error if present"
      )
    end

    response(302, "Found - Redirect to frontend", Schema.ref(:OAuthCallbackResponse),
      description:
        "Successful OAuth callback - redirects user to frontend application with auth status"
    )

    response(400, "Bad Request", Schema.ref(:ErrorResponse),
      description: "Invalid authorization code or missing required parameters"
    )

    response(401, "Unauthorized", Schema.ref(:ErrorResponse),
      description: "OAuth state mismatch or invalid session"
    )
  end

  @doc """
  Handles Dropbox OAuth callback.

  This function is automatically called by Dropbox's OAuth servers after user authorization.
  It processes the authorization code and redirects the user back to the frontend.
  """
  @spec dropbox_callback(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def dropbox_callback(conn, %{"code" => code} = params) do
    conn.assigns[:current_user]
    |> CloudAuth.handle_oauth_callback(params, :dropbox, code)
    |> then(&redirect(conn, to: &1))
  end

  swagger_path :onedrive_callback do
    get("/auth/onedrive/callback")
    summary("OneDrive OAuth callback endpoint")

    description("""
    **Internal OAuth callback endpoint - automatically called by Microsoft OAuth servers.**

    This endpoint is not intended for direct developer use. It is automatically invoked by Microsoft's
    OAuth servers after a user completes the authorization process. The endpoint:

    - Receives the authorization code from Microsoft
    - Exchanges it for access tokens
    - Stores the tokens for future API calls
    - Redirects the user back to the frontend application

    Developers should use the `/auth/onedrive` endpoint to initiate the OAuth flow.
    """)

    operation_id("handleOneDriveOAuthCallback")
    produces("text/html")
    tag("OAuth Callbacks")

    parameters do
      code(:query, :string, "Authorization code from Microsoft OAuth servers",
        required: true,
        description: "Temporary code provided by Microsoft after user authorization"
      )

      state(:query, :string, "OAuth state parameter for CSRF protection",
        required: false,
        description: "State value originally sent to Microsoft for security verification"
      )

      error(:query, :string, "Error code if authorization was denied",
        required: false,
        description: "Present only when user denies authorization or an error occurs"
      )

      error_description(:query, :string, "Human-readable error description",
        required: false,
        description: "Additional details about the error if present"
      )
    end

    response(302, "Found - Redirect to frontend", Schema.ref(:OAuthCallbackResponse),
      description:
        "Successful OAuth callback - redirects user to frontend application with auth status"
    )

    response(400, "Bad Request", Schema.ref(:ErrorResponse),
      description: "Invalid authorization code or missing required parameters"
    )

    response(401, "Unauthorized", Schema.ref(:ErrorResponse),
      description: "OAuth state mismatch or invalid session"
    )
  end

  @doc """
  Handles OneDrive OAuth callback.

  This function is automatically called by Microsoft's OAuth servers after user authorization.
  It processes the authorization code and redirects the user back to the frontend.
  """
  @spec onedrive_callback(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def onedrive_callback(conn, %{"code" => code} = params) do
    conn.assigns[:current_user]
    |> CloudAuth.handle_oauth_callback(params, :onedrive, code)
    |> then(&redirect(conn, to: &1))
  end
end
