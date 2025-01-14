defmodule WraftDocWeb.NotificationChannel do
  @moduledoc """
  Channel for handling real-time notification updates via WebSocket.
  Manages client connections and message broadcasting.
  """

  use Phoenix.Channel
  require Logger

  alias WraftDoc.Notifications
  alias WraftDoc.Notifications.NotificationServer
  @impl true
  def join("notification:" <> user_id, _payload, socket) do
    with {:ok, parsed_id} <- parse_user_id(user_id),
         :ok <- authorize_user(parsed_id, socket.assigns.current_user),
         :ok <- NotificationServer.subscribe(user_id) do
      {:ok, assign(socket, :user_id, parsed_id)}
    else
      {:error, _reason} = error ->
        error
    end
  end

  @impl true
  def handle_in("list_notifications", _payload, socket) do
    notifications =
      socket.assigns.current_user
      |> Notifications.list_notifications()
      |> Enum.map(fn x -> Notifications.get_notification_message(x) end)
      |> Enum.filter(fn x -> !is_nil(x.message) end)

    read_status = Enum.any?(notifications, fn x -> !x.read end)
    {:reply, {:ok, %{notifications: notifications, read_status: read_status}}, socket}
  end

  @impl true
  def handle_in("read_all", _, socket) do
    notifications =
      socket.assigns.current_user
      |> Notifications.list_notifications()
      |> Enum.filter(fn x -> !x.read end)
      |> Enum.map(fn x -> Notifications.read_notification(x) end)
      |> Enum.map(fn x -> Notifications.get_notification_message(x) end)

    {:reply, {:ok, %{notifications: notifications, read_status: true}}}
  end

  def handle_in("ping", payload, socket) do
    {:reply, {:ok, payload}, socket}
  end

  def handle_in("shout", payload, socket) do
    broadcast!(socket, "shout", payload)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:new_notification, message}, socket) do
    {:noreply, push(socket, "message_created", %{body: message})}
  end

  @impl true
  def handle_info({:notification_updated, message}, socket) do
    {:noreply, push(socket, "notification_updated", %{body: message})}
  end

  @impl true
  def handle_info({:all_notifications_read, metadata}, socket) do
    {:noreply, push(socket, "all_notifications_read", metadata)}
  end

  defp parse_user_id(user_id) do
    case Integer.parse(user_id) do
      {id, ""} -> {:ok, id}
      _ -> {:error, :invalid_user_id}
    end
  end

  def broad_cast(message, user) do
    socket = create_socket(user)
    broadcast!(socket, "message_created", %{body: message})
    {:noreply, socket}
  end

  def create_socket(current_user) do
    socket = %{
      channel: WraftDocWeb.NotificationChannel,
      endpoint: WraftDocWeb.Endpoint,
      handler: WraftDocWeb.UserSocket,
      id: nil,
      join_ref: "1",
      joined: true,
      private: %{log_handle_in: :debug, log_join: :info},
      pubsub_server: WraftDoc.PubSub,
      ref: nil,
      serializer: Phoenix.Transports.V2.WebSocketSerializer,
      topic: "notification:" <> Integer.to_string(current_user.id),
      transport: Phoenix.Transports.WebSocket,
      transport_name: :websocket,
      vsn: "2.0.0"
    }

    %Phoenix.Socket{}
    |> assign(:current_user, current_user)
    |> Map.merge(socket)
  end

  defp authorize_user(user_id, %{id: current_user_id}) do
    if user_id == current_user_id do
      :ok
    else
      {:error, :unauthorized}
    end
  end

  defp authorize_user(_, _), do: {:error, :invalid_user}
  @impl true
  def terminate(_reason, socket) do
    NotificationServer.unsubscribe(socket.assigns.user_id)
    :ok
  end
end
