defmodule WraftDocWeb.UserSocket do
  use Phoenix.Socket
  import Guardian.Phoenix.Socket
  alias WraftDoc.{Account, Repo}

  # 30 minutes in milliseconds
  @cache_ttl 30 * 60 * 1000

  # Channels (keep your existing channels)
  channel("notification:*", WraftDocWeb.NotificationChannel)
  channel("doc_room:*", WraftDocWeb.DocumentChannel)
  channel("room:*", WraftDocWeb.NotificationChannel)

  @doc """
  The socket is used to connect to the server and authenticate the user.
  """
  def connect(%{"token" => token} = _params, socket, _connect_info) do
    cache_key = token_hash(token)

    case WraftDoc.SessionCache.get(cache_key) do
      {:ok, user} ->
        {:ok, assign(socket, :current_user, user)}

      {:error, :not_found} ->
        with {:ok, authed_socket} <- authenticate(socket, WraftDocWeb.Guardian, token),
             {:ok, user} <- fetch_user(authed_socket) do
          WraftDoc.SessionCache.put(cache_key, user, @cache_ttl)
          {:ok, assign(authed_socket, :current_user, user)}
        else
          _ -> :error
        end
    end
  end

  defp token_hash(token) do
    Base.encode16(:crypto.hash(:sha256, token))
  end

  defp fetch_user(socket) do
    user =
      socket
      |> current_resource()
      |> Account.get_user_by_email()
      |> Repo.preload([:profile, :roles])

    {:ok, Map.put(user, :role_names, Enum.map(user.roles, & &1.name))}
  end

  # Use actual user ID for targeted broadcasts
  def id(socket), do: "user_socket:#{socket.assigns.current_user.id}"
end
