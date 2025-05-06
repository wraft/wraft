defmodule WraftDocWeb.Api.V1.CloudServiceController do
  use WraftDocWeb, :controller

  alias WraftDoc.AuthTokens
  alias WraftDoc.AuthTokens.AuthToken
  alias WraftDoc.GoogleDrive
  alias WraftDoc.Repo

  def authorize(conn, _params) do
    auth_url = GoogleDrive.get_authorize_url()
    redirect(conn, external: auth_url)
  end

  def callback(conn, %{"code" => code}) do
    user = conn.assigns.current_user

    case GoogleDrive.exchange_code_for_token(code) do
      {:ok, tokens} ->
        expiry_datetime =
          tokens.expires_at
          |> DateTime.from_unix!()
          |> DateTime.to_naive()

        AuthTokens.insert_auth_token!(user, %{
          value: tokens.access_token,
          token_type: :google_oauth,
          expiry_datetime: expiry_datetime,
          meta_data: %{
            "refresh_token" => tokens.refresh_token
          }
        })

        conn
        |> json("Google Drive connected successfully.")
        |> redirect(to: "/drive/files")

      {:error, reason} ->
        conn
        |> json("Failed to connect Google Drive: #{inspect(reason)}")
        |> redirect(to: "/drive/authorize")
    end
  end

  def list_files(conn, _params) do
    user = conn.assigns.current_user

    case AuthTokens.get_auth_token_by_type(user.id, :google_oauth) do
      %AuthToken{} = token ->
        handle_file_listing(conn, token)

      nil ->
        conn
        |> json("No Google Drive connection found.")
        |> redirect(to: "/drive/authorize")
    end
  end

  defp handle_file_listing(
         conn,
         %AuthToken{value: access_token, meta_data: %{"refresh_token" => refresh_token}} = token
       ) do
    case GoogleDrive.list_files(access_token) do
      {:ok, %{"files" => files}} ->
        render(conn, "files.html", files: files)

      {:error, :token_expired} ->
        refresh_and_retry_listing(conn, token, refresh_token)

      {:error, message} ->
        conn
        |> json("Error accessing Google Drive: #{message}")
        |> redirect(to: "/dashboard")
    end
  end

  defp refresh_and_retry_listing(conn, token, refresh_token) do
    case GoogleDrive.refresh_token(refresh_token) do
      {:ok, new_tokens} ->
        # Use the new refresh token if provided, otherwise keep the existing one
        new_refresh_token = new_tokens.refresh_token || refresh_token

        expiry_datetime =
          new_tokens.expires_at
          |> DateTime.from_unix!()
          |> DateTime.to_naive()

        updated_token =
          token
          |> Ecto.Changeset.change(%{
            value: new_tokens.access_token,
            expiry_datetime: expiry_datetime,
            meta_data: %{
              "refresh_token" => new_refresh_token
            }
          })
          |> Repo.update!()

        # Get files with the new token
        case GoogleDrive.list_files(updated_token.value) do
          {:ok, %{"files" => files}} ->
            render(conn, "files.html", files: files)

          {:error, message} ->
            conn
            |> json("Error accessing Google Drive: #{message}")
            |> redirect(to: "/dashboard")
        end

      {:error, _reason} ->
        conn
        |> json("Google Drive session expired. Please reconnect.")
        |> redirect(to: "/drive/authorize")
    end
  end
end
