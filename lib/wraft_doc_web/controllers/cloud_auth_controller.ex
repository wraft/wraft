defmodule WraftDocWeb.Api.V1.CloudImportAuthController do
  @moduledoc """
  Controller for handling cloud service interactions with Google Drive, Dropbox, and OneDrive.
  Provides endpoints for authentication, file exploration, and file operations.
  """

  use WraftDocWeb, :controller

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.CloudImport.CloudAuth
  alias WraftDoc.CloudImport.CloudAuthTokens, as: AuthTokens
  require Logger

  @services [:google_drive, :dropbox, :onedrive]

  @doc """
  Redirects to cloud service OAuth login URL.
  """
  @spec login_url(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def login_url(conn, %{"service" => service}) do
    with service <- String.to_existing_atom(service),
         true <- service in @services,
         redirect_url when is_binary(redirect_url) <- CloudAuth.authorize_url!(service) do
      # IO.inspect(redirect_url, label: "Redirect URL for #{service}")
      redirect(conn, external: redirect_url)
    else
      false ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Invalid service specified"})

      error ->
        Logger.error("Failed to generate login URL: #{inspect(error)}")

        conn
        |> put_flash(:error, "Failed to initiate authentication")
        |> redirect(to: "/")
    end
  end

  @doc """
  Handles Google Drive OAuth callback.
  """
  @spec google_callback(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def google_callback(conn, %{"code" => code} = params) do
    user = conn.assigns[:current_user]

    with {:ok, token_data} <- CloudAuth.google_drive_token(code),
         {:ok, _token} <- AuthTokens.save_cloud_import_token(user, token_data, :google_drive) do
      redirect(conn, to: get_redirect_path(params))
    else
      {:error, reason} ->
        Logger.error("Google Drive authentication failed: #{inspect(reason)}")

        conn
        |> put_flash(:error, "Google Drive authentication failed")
        |> redirect(to: "/")
    end
  end

  @doc """
  Handles Dropbox OAuth callback.
  """
  @spec dropbox_callback(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def dropbox_callback(conn, %{"code" => code} = params) do
    user = conn.assigns[:current_user]

    with {:ok, token_data} <- CloudAuth.dropbox_token(code),
         {:ok, _token} <- AuthTokens.save_cloud_import_token(user, token_data, :dropbox) do
      redirect(conn, to: get_redirect_path(params))
    else
      {:error, reason} ->
        Logger.error("Dropbox authentication failed: #{inspect(reason)}")

        conn
        |> put_flash(:error, "Dropbox authentication failed")
        |> redirect(to: "/")
    end
  end

  @doc """
  Handles OneDrive OAuth callback.
  """
  @spec onedrive_callback(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def onedrive_callback(conn, %{"code" => code} = params) do
    user = conn.assigns[:current_user]

    with {:ok, token_data} <- CloudAuth.onedrive_token(code),
         {:ok, _token} <- AuthTokens.save_cloud_import_token(user, token_data, :onedrive) do
      redirect(conn, to: get_redirect_path(params))
    else
      {:error, reason} ->
        Logger.error("OneDrive authentication failed: #{inspect(reason)}")

        conn
        |> put_flash(:error, "OneDrive authentication failed")
        |> redirect(to: "/")
    end
  end

  #  @spec logout(Plug.Conn.t(), map()) :: Plug.Conn.t()
  # def logout(conn, %{"service" => service}) do
  #   service = String.to_existing_atom(service)
  #   AuthTokens.revoke_tokens(get_token_type(service))

  #   json(conn, %{
  #     status: "success",
  #     message: "Logged out from #{service} successfully"
  #   })
  # end

  # def logout(conn, _params) do
  #   Enum.each(@services, fn service ->
  #     AuthTokens.revoke_tokens(get_token_type(service))
  #   end)

  #   json(conn, %{status: "success", message: "Logged out from all services"})
  # end

  defp get_redirect_path(params) do
    case params do
      %{"redirect_to" => path} when is_binary(path) -> path
      _ -> "/"
    end
  end
end
