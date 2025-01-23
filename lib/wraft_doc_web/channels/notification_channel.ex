defmodule WraftDocWeb.NotificationChannel do
  @moduledoc """
  Channel for handling real-time notification updates via WebSocket.
  Manages client connections and message broadcasting.
  """

  use Phoenix.Channel
  require Logger

  alias WraftDoc.Notifications.NotificationServer
  @impl true

  def join("notification:" <> user, _payload, socket) do
    if authorized?(user, socket.assigns.current_user) do
      {:ok, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  def broad_cast(message, user) do
    socket = create_socket(user)
    broadcast!(socket, "message_created", %{body: message})
    {:noreply, socket}
  end

  def create_socket(%{id: user_id} = current_user) do
    socket = build_socket_params(user_id)

    %Phoenix.Socket{}
    |> assign(:current_user, current_user)
    |> Map.merge(socket)
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

  defp build_socket_params(user_id) do
    %{
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
      topic: "notification:" <> user_id,
      transport: Phoenix.Transports.WebSocket,
      transport_name: :websocket,
      vsn: "2.0.0"
    }
  end

  defp authorized?(user_id, %{id: current_user_id}) do
    if user_id == current_user_id do
      :ok
    else
      {:error, :unauthorized}
    end
  end

  @impl true
  def terminate(_reason, socket) do
    NotificationServer.unsubscribe(socket.assigns.user_id)
    :ok
  end
end
