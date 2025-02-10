defmodule WraftDocWeb.NotificationChannel do
  @moduledoc """
  Channel for handling real-time notification updates via WebSocket.
  Manages client connections and message broadcasting.
  """

  use Phoenix.Channel
  require Logger

  @impl true

  @doc """
  Handles joining a "notification" channel for a specific user
  """
  @spec join(String.t(), map(), Phoenix.Socket.t()) :: {:ok, Phoenix.Socket.t()} | {:error, map()}
  def join("notification:" <> user_id, _payload, socket) do
    if authorized?(user_id, socket.assigns.current_user) do
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

  defp create_socket(%{id: user_id} = current_user) do
    socket = build_socket_params(user_id)

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
end
