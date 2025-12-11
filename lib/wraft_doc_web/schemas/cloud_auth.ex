defmodule WraftDocWeb.Schemas.CloudAuth do
  @moduledoc """
  Schema for CloudAuth request and response
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

  defmodule AuthLoginUrlRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Auth Login URL Request",
      description: "Request parameters for generating OAuth login URL",
      type: :object,
      properties: %{
        provider: %Schema{
          type: :string,
          description: "Provider to authenticate with",
          enum: ["google_drive", "dropbox", "onedrive"]
        }
      },
      required: [:provider],
      example: %{
        "provider" => "google_drive"
      }
    })
  end

  defmodule AuthLoginUrlResponse do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Auth Login URL Response",
      description: "Successful response containing OAuth redirect URL",
      type: :object,
      properties: %{
        status: %Schema{type: :string, description: "Status of the request", example: "success"},
        redirect_url: %Schema{
          type: :string,
          description: "URL to redirect for OAuth authentication"
        }
      },
      example: %{
        "status" => "success",
        "redirect_url" =>
          "https://accounts.google.com/o/oauth2/auth?response_type=code&client_id=12345&redirect_uri=https%3A%2F%2Fyourapp.com%2Fauth%2Fcallback&scope=email%20profile&state=abc123"
      }
    })
  end

  defmodule OAuthCallbackResponse do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "OAuth Callback Response",
      description: "Response from OAuth callback - redirects to frontend",
      type: :object,
      properties: %{
        message: %Schema{type: :string, description: "Informational message about the redirect"},
        redirect_location: %Schema{
          type: :string,
          description: "Frontend URL where user will be redirected"
        }
      },
      example: %{
        "message" => "Redirecting to frontend application",
        "redirect_location" => "https://yourapp.com/dashboard?auth=success"
      }
    })
  end

  defmodule ErrorResponse do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Error Response",
      description: "Standard error response format",
      type: :object,
      properties: %{
        error: %Schema{type: :string, description: "Error message"},
        details: %Schema{type: :string, description: "Additional error details"}
      },
      example: %{
        "error" => "Invalid provider specified",
        "details" => "Supported providers: google_drive, dropbox, onedrive"
      }
    })
  end
end
