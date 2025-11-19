defmodule WraftDocWeb.Plug.ApiKeyAuth do
  @moduledoc """
  Plug for API Key authentication.

  This plug attempts to authenticate requests using an API key from the X-API-Key header.
  If a valid API key is found:
  - Sets conn.assigns.current_user to the user associated with the API key
  - Sets conn.assigns.current_organisation to the organisation
  - Sets conn.assigns.api_key to the API key struct (for audit purposes)
  - Sets conn.assigns.authenticated_via to :api_key

  If no API key is provided or invalid, the plug does nothing and lets the
  request continue to the next authentication method (JWT).
  """

  import Plug.Conn
  require Logger

  alias WraftDoc.ApiKeys

  def init(opts), do: opts

  def call(conn, _opts) do
    # Only attempt API key auth if we don't already have a current_user
    # (i.e., JWT auth hasn't succeeded)
    if conn.assigns[:current_user] do
      conn
    else
      case get_api_key_from_header(conn) do
        nil ->
          # No API key provided, continue to next auth method
          conn

        api_key ->
          authenticate_with_api_key(conn, api_key)
      end
    end
  end

  defp get_api_key_from_header(conn) do
    case get_req_header(conn, "x-api-key") do
      [api_key | _] when is_binary(api_key) and byte_size(api_key) > 0 ->
        api_key

      _ ->
        nil
    end
  end

  defp authenticate_with_api_key(conn, api_key_string) do
    remote_ip = get_remote_ip(conn)

    case ApiKeys.verify_api_key(api_key_string, remote_ip) do
      {:ok, %{api_key: api_key, user: user, organisation: organisation}} ->
        # Check rate limit
        case ApiKeys.check_rate_limit(api_key) do
          {:ok, _} ->
            conn
            |> assign(:current_user, user)
            |> assign(:current_organisation, organisation)
            |> assign(:api_key, api_key)
            |> assign(:authenticated_via, :api_key)

          {:error, :rate_limit_exceeded} ->
            Logger.warning("API key rate limit exceeded: #{api_key.id}")
            send_error_response(conn, 429, "Rate limit exceeded")
        end

      {:error, :invalid_api_key} ->
        Logger.warning("Invalid API key provided")
        send_error_response(conn, 401, "Invalid API key")

      {:error, :api_key_expired} ->
        Logger.warning("Expired API key used")
        send_error_response(conn, 401, "API key has expired")

      {:error, :api_key_inactive} ->
        Logger.warning("Inactive API key used")
        send_error_response(conn, 401, "API key is inactive")

      {:error, :ip_not_whitelisted} ->
        Logger.warning("API key used from non-whitelisted IP")
        send_error_response(conn, 403, "IP address not authorized for this API key")

      {:error, :user_not_found} ->
        Logger.warning("API key user not found")
        send_error_response(conn, 401, "User associated with API key not found")

      {:error, reason} ->
        Logger.warning("API key authentication failed: #{inspect(reason)}")
        send_error_response(conn, 401, "API key authentication failed")
    end
  end

  defp get_remote_ip(conn) do
    # Try to get the real IP from common headers (for proxy/load balancer support)
    case get_req_header(conn, "x-forwarded-for") do
      [ip | _] ->
        # X-Forwarded-For can contain multiple IPs, take the first
        ip
        |> String.split(",")
        |> List.first()
        |> String.trim()

      [] ->
        case get_req_header(conn, "x-real-ip") do
          [ip | _] -> ip
          [] -> conn.remote_ip |> :inet.ntoa() |> to_string()
        end
    end
  end

  defp send_error_response(conn, status, message) do
    body = Jason.encode!(%{errors: message})

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, body)
    |> halt()
  end
end
