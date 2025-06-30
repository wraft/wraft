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
            "provider" => "google"
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
            "details" => "Supported providers: google, github, microsoft"
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
  - provider: The provider to authenticate with (e.g., "google", "github")

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
      "details": "Supported providers: google, github, microsoft"
    }
    ```
  - 401: Unauthorized request
  """
  @spec login_url(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def login_url(conn, %{"provider" => provider}) do
    user = conn.assigns[:current_user]

    with provider <- String.to_existing_atom(provider),
         true <- provider in @providers,
         {:ok, redirect_url, session_params} <- CloudAuth.authorize_url!(provider) do
      StateStore.put(user.id, provider, session_params)

      Logger.info("Redirecting to #{provider} OAuth: #{redirect_url}")

      json(conn, %{
        status: "success",
        redirect_url: redirect_url
      })
    end
  end

  @doc """
  Handles Google Drive OAuth callback.
  """
  @spec google_callback(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def google_callback(conn, %{"code" => code} = params) do
    conn.assigns[:current_user]
    |> CloudAuth.handle_oauth_callback(params, :google_drive, code)
    |> then(&redirect(conn, to: &1))
  end

  @doc """
  Handles Dropbox OAuth callback.
  """
  @spec dropbox_callback(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def dropbox_callback(conn, %{"code" => code} = params) do
    conn.assigns[:current_user]
    |> CloudAuth.handle_oauth_callback(params, :dropbox, code)
    |> then(&redirect(conn, to: &1))
  end

  @doc """
  Handles OneDrive OAuth callback.
  """
  @spec onedrive_callback(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def onedrive_callback(conn, %{"code" => code} = params) do
    conn.assigns[:current_user]
    |> CloudAuth.handle_oauth_callback(params, :onedrive, code)
    |> then(&redirect(conn, to: &1))
  end
end
