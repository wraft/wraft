defmodule WraftDocWeb.Api.V1.CloudImportAuthController do
  @moduledoc """
  Controller for handling cloud service interactions with Google Drive, Dropbox, and OneDrive.
  Provides endpoints for authentication, file exploration, and file operations.
  Now using Assent for OAuth2 authentication.
  """

  use WraftDocWeb, :controller
  use PhoenixSwagger

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.CloudImport.CloudAuth
  alias WraftDoc.CloudImport.RepositoryCloudTokens, as: AuthTokens
  alias WraftDoc.CloudImport.StateStore
  require Logger

  @services [:google_drive, :dropbox, :onedrive]
  def swagger_definitions do
    %{
      AuthLoginUrlRequest:
        swagger_schema do
          title("Auth Login URL Request")
          description("Request parameters for generating OAuth login URL")

          properties do
            service(:string, "Service to authenticate with",
              required: true,
              enum: Enum.map(@services, &Atom.to_string/1)
            )
          end

          example(%{
            "service" => "google"
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
            "error" => "Invalid service specified",
            "details" => "Supported services: google, github, microsoft"
          })
        end
    }
  end

  swagger_path :login_url do
    get("/auth/{service}")
    summary("Generate OAuth login URL")

    description("""
    Generates a redirect URL for OAuth authentication with the specified service.
    Stores OAuth session parameters for later verification during the callback phase.
    """)

    operation_id("generateOAuthRedirectUrl")
    produces("application/json")
    tag("Authentication")

    parameters do
      service(:path, :string, "Service to authenticate with",
        required: true,
        enum: Enum.map(@services, &Atom.to_string/1),
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
        "error" => "Invalid service specified",
        "details" => "Supported services: google_drive, dropbox, onedrive"
      }
    )
  end

  @doc """
  Generates OAuth login URL for the specified service.

  ## Parameters
  - service: The service to authenticate with (e.g., "google", "github")

  ## Responses
  - 200: Returns redirect URL for OAuth flow
    ```json
    {
      "status": "success",
      "redirect_url": "https://accounts.google.com/o/oauth2/auth?..."
    }
    ```
  - 400: Invalid service parameter
    ```json
    {
      "error": "Invalid service specified",
      "details": "Supported services: google, github, microsoft"
    }
    ```
  - 401: Unauthorized request
  """
  @spec login_url(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def login_url(conn, %{"service" => service}) do
    user = conn.assigns[:current_user]

    with service <- String.to_existing_atom(service),
         true <- service in @services,
         {:ok, redirect_url, session_params} <- CloudAuth.authorize_url!(service) do
      StateStore.put(user.id, service, session_params)

      Logger.info("Redirecting to #{service} OAuth: #{redirect_url}")

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
    handle_oauth_callback(conn, params, :google_drive, code)
  end

  @doc """
  Handles Dropbox OAuth callback.
  """
  @spec dropbox_callback(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def dropbox_callback(conn, %{"code" => code} = params) do
    handle_oauth_callback(conn, params, :dropbox, code)
  end

  @doc """
  Handles OneDrive OAuth callback.
  """
  @spec onedrive_callback(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def onedrive_callback(conn, %{"code" => code} = params) do
    handle_oauth_callback(conn, params, :onedrive, code)
  end

  @doc """
  Generic endpoint for handling OAuth errors.
  """
  @spec oauth_error(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def oauth_error(conn, %{"error" => error, "error_description" => description} = params) do
    service = get_service_from_state(params["state"])

    Logger.error("OAuth error for #{service}: #{error} - #{description}")

    # |> put_flash(:error, "Authentication failed: #{description}")
    redirect(conn, to: get_redirect_path(params, "/"))
  end

  def oauth_error(conn, %{"error" => error} = params) do
    service = get_service_from_state(params["state"])

    Logger.error("OAuth error for #{service}: #{error}")

    # |> put_flash(:error, "Authentication failed")
    redirect(conn, to: get_redirect_path(params, "/"))
  end

  # @doc """
  # Revokes tokens for a specific service or all services.
  # """

  # @spec logout(Plug.Conn.t(), map()) :: Plug.Conn.t()
  # def logout(conn, %{"service" => service}) do
  #   user = conn.assigns[:current_user]

  #   with service <- String.to_existing_atom(service),
  #        true <- service in @services,
  #        :ok <- AuthTokens.revoke_tokens(user, service) do
  #     json(conn, %{
  #       status: "success",
  #       message: "Logged out from #{service} successfully"
  #     })
  #   else
  #     false ->
  #       #  |> put_status(:bad_request)
  #       json(conn, %{error: "Invalid service specified"})

  #     {:error, reason} ->
  #       Logger.error("Failed to revoke tokens for #{service}: #{inspect(reason)}")

  #       # |> put_status(:internal_erver_error)
  #       json(conn, %{error: "Failed to revoke tokens", details: inspect(reason)})
  #   end
  # end

  # def logout(conn, _params) do
  #   user = conn.assigns[:current_user]

  #   results =
  #     Enum.map(@services, fn service ->
  #       case AuthTokens.revoke_tokens(user, service) do
  #         :ok -> {service, :ok}
  #         {:error, reason} -> {service, {:error, reason}}
  #       end
  #     end)

  #   errors = Enum.filter(results, fn {_service, result} -> match?({:error, _}, result) end)

  #   if Enum.empty?(errors) do
  #     json(conn, %{status: "success", message: "Logged out from all services"})
  #   else
  #     Logger.warning("Some services failed to logout: #{inspect(errors)}")

  #     json(conn, %{
  #       status: "partial_success",
  #       message: "Logged out from most services",
  #       errors: Enum.into(errors, %{})
  #     })
  #   end
  # end

  # @doc """
  # Checks authentication status for all services.
  # """

  # @spec status(Plug.Conn.t(), map()) :: Plug.Conn.t()
  # def status(conn, _params) do
  #   user = conn.assigns[:current_user]

  #   status_map =
  #     Enum.into(@services, %{}, fn service ->
  #       token_info = build_service_status(user, service)
  #       {service, token_info}
  #     end)

  #   json(conn, %{status: status_map})
  # end

  # defp build_service_status(user, service) do
  #   case AuthTokens.get_valid_token(user, service) do
  #     {:ok, %{expires_at: expires_at}} ->
  #       %{authenticated: true, expires_at: expires_at}

  #     {:ok, _} ->
  #       %{authenticated: true, expires_at: nil}

  #     {:error, _} ->
  #       %{authenticated: false}
  #   end
  # end

  # Private functions

  defp handle_oauth_callback(conn, params, service, code) do
    user = conn.assigns[:current_user]

    with {:ok, _user_data, token_data} <-
           CloudAuth.get_token(service, user.id, code),
         {:ok, _token} <-
           AuthTokens.save_token_data(user, user.organisation_id, token_data, service) do
      Logger.info("Successfully authenticated #{user.name} with #{token_data["access_token"]}")

      # |> put_flash(:info, "Successfully connected to #{format_service_name(service)}")
      redirect(conn, to: get_redirect_path(params))
    else
      {:error, reason} ->
        Logger.error(
          "#{format_service_name(service)} authentication failed for user #{user.id}: #{inspect(reason)}"
        )

        # |> put_flash(:error, "#{format_service_name(service)} authentication failed")
        redirect(conn, to: get_redirect_path(params, "/"))
    end
  end

  defp get_redirect_path(params, default \\ "/") do
    case params do
      %{"redirect_to" => path} when is_binary(path) and path != "" ->
        path

      %{"state" => state} when is_binary(state) ->
        # Try to extract redirect path from state parameter
        extract_redirect_from_state(state, default)

      _ ->
        default
    end
  end

  defp extract_redirect_from_state(state, default) do
    # State might contain encoded redirect information
    case String.split(state, "_", parts: 4) do
      [_service, "auth", _random, redirect_path] when redirect_path != "" ->
        "/" <> redirect_path

      _ ->
        default
    end
  end

  defp get_service_from_state(nil), do: "unknown"

  defp get_service_from_state(state) do
    case String.split(state, "_", parts: 2) do
      [service, _] -> service
      _ -> "unknown"
    end
  end

  defp format_service_name(:google_drive), do: "Google Drive"
  defp format_service_name(:dropbox), do: "Dropbox"
  defp format_service_name(:onedrive), do: "OneDrive"
  defp format_service_name(service), do: service |> to_string() |> String.capitalize()
end
