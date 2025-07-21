defmodule WraftDocWeb.UserSocket do
  use Phoenix.Socket

  import Guardian.Phoenix.Socket
  alias WraftDoc.{Account, Repo}

  # 30 minutes in milliseconds
  @cache_ttl 30 * 60 * 1000

  channel("user_notification:*", WraftDocWeb.NotificationChannel)
  channel("organisation_notification:*", WraftDocWeb.NotificationChannel)
  channel("role_group_notification:*", WraftDocWeb.NotificationChannel)
  channel("doc_room:*", WraftDocWeb.DocumentChannel)

  @doc """
  The socket is used to connect to the server and authenticate the user.
  """
  def connect(%{"token" => token} = _params, socket, _connect_info) do
    cache_key = token_cache_key(token)

    case WraftDoc.SessionCache.get(cache_key) do
      {:ok, user} when is_map(user) ->
        if user_data_fresh?(user) do
          {:ok, assign(socket, :current_user, user)}
        else
          authenticate_and_cache(token, socket, cache_key)
        end

      {:error, :not_found} ->
        authenticate_and_cache(token, socket, cache_key)
    end
  end

  def connect(_params, _socket, _connect_info) do
    {:error, :unauthorized_connection}
  end

  def invalidate_user_cache(token) when is_binary(token) do
    cache_key = token_cache_key(token)
    WraftDoc.SessionCache.delete(cache_key)
  end

  def invalidate_user_cache(_), do: :ok

  def invalidate_user_cache_pattern(user_id) when is_binary(user_id) do
    pattern = {"user:" <> user_id, :_}
    WraftDoc.SessionCache.delete_pattern(pattern)
  end

  defp authenticate_and_cache(token, socket, cache_key) do
    with {:ok, authed_socket} <- authenticate(socket, WraftDocWeb.Guardian, token),
         {:ok, user} <- fetch_user(authed_socket) do
      case WraftDoc.SessionCache.put(cache_key, user, @cache_ttl) do
        :ok ->
          {:ok, assign(authed_socket, :current_user, user)}

        {:error, :cache_full} ->
          # Still allow authentication even if cache is full
          {:ok, assign(authed_socket, :current_user, user)}
      end
    else
      _error -> :error
    end
  end

  defp token_cache_key(token) do
    "user_token:" <> String.slice(token, 0, 16)
  end

  defp user_data_fresh?(%{cached_at: cached_at}) when is_integer(cached_at) do
    now = System.system_time(:millisecond)
    now - cached_at < 5 * 60 * 1000
  end

  defp user_data_fresh?(_), do: false

  defp fetch_user(socket) do
    user =
      socket
      |> current_resource()
      |> Account.get_user_by_email()
      |> Repo.preload([:profile, :roles])

    user_with_metadata =
      user
      |> Map.put(:role_names, Enum.map(user.roles, & &1.name))
      |> Map.put(:cached_at, System.system_time(:millisecond))

    {:ok, user_with_metadata}
  end

  def id(socket), do: "user_socket:#{socket.assigns.current_user.id}"
end
