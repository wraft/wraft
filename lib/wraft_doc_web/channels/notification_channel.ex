defmodule WraftDocWeb.NotificationChannel do
  @moduledoc """
  Channel module for notification
  """
  use Phoenix.Channel
  alias WraftDoc.Notifications

  def join("notification:" <> user_id, _payload, socket) do
    if authorized?(user_id, socket.assigns.current_user) do
      {:ok, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  def handle_in("notifications:list", _payload, socket) do
    notifications =
      socket.assigns.current_user
      |> Notifications.list_notifications()
      |> Enum.map(fn x -> Notifications.get_notification_message(x) end)
      |> Enum.filter(fn x -> !is_nil(x.message) end)

    read_status = Enum.any?(notifications, fn x -> !x.read end)
    {:reply, {:ok, %{notifications: notifications, read_status: read_status}}, socket}
  end

  def handle_in("ping", payload, socket) do
    {:reply, {:ok, payload}, socket}
  end

  def handle_in("notifications:read_all", _, socket) do
    notifications =
      socket.assigns.current_user
      |> Notifications.list_notifications()
      |> Enum.filter(fn x -> !x.read end)
      |> Enum.map(fn x -> Notifications.read_notification(x) end)
      |> Enum.map(fn x -> Notifications.get_notification_message(x) end)

    {:reply, {:ok, %{notifications: notifications, read_status: true}}}
  end

  # It is also common to receive messages from the client and
  # broadcast to everyone in the current topic (room:lobby).
  def handle_in("shout", payload, socket) do
    broadcast(socket, "shout", payload)
    {:noreply, socket}
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

  defp authorized?(user_id, current_user) do
    user_id === current_user.id
  end
end
