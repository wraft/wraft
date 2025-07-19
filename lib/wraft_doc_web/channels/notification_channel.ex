defmodule WraftDocWeb.NotificationChannel do
  @moduledoc """
  Channel for handling real-time notification updates via WebSocket.
  Manages client connections and message broadcasting.
  """

  use Phoenix.Channel
  require Logger

  alias WraftDoc.Account
  alias WraftDocWeb.Api.V1.NotificationView

  @impl true

  @doc """
  Handles joining a "notification" channel for a specific user
  """
  @spec join(String.t(), map(), Phoenix.Socket.t()) :: {:ok, Phoenix.Socket.t()} | {:error, map()}
  def join("user_notification:" <> user_id, _payload, socket) do
    if authorized?(:user, user_id, socket.assigns.current_user) do
      {:ok, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  def join("role_group_notification:" <> role_group_id, _payload, socket) do
    if authorized?(:role, role_group_id, socket.assigns.current_user) do
      {:ok, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  def join("organisation_notification:" <> organisation_id, _payload, socket) do
    if authorized?(:organisation, organisation_id, socket.assigns.current_user) do
      {:ok, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  @spec broadcast(Notification.t(), User.t()) :: {:noreply, Phoenix.Socket.t()}
  def broadcast(notification, user) do
    socket = create_socket(notification, user)
    payload = create_notification_payload(notification)
    broadcast!(socket, "notification", %{body: payload})
    {:noreply, socket}
  end

  defp create_socket(notification, current_user) do
    socket = build_socket_params(notification)

    %Phoenix.Socket{}
    |> assign(:current_user, current_user)
    |> Map.merge(socket)
  end

  defp build_socket_params(notification) do
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
      topic: get_topic(notification),
      transport: Phoenix.Transports.WebSocket,
      transport_name: :websocket,
      vsn: "2.0.0"
    }
  end

  defp get_topic(%{channel: channel, channel_id: channel_id} = _notification),
    do: "#{Atom.to_string(channel)}:#{channel_id}"

  def create_notification_payload(notification) do
    %{read: false, seen_at: nil}
    |> Map.put(:notification, notification)
    |> then(&NotificationView.render("user_notification.json", %{user_notification: &1}))
  end

  defp authorized?(:user, user_id, %{id: current_user_id})
       when user_id == current_user_id,
       do: :ok

  defp authorized?(:organisation, organisation_id, %{current_org_id: current_org_id})
       when organisation_id == current_org_id,
       do: :ok

  # TODO: authorize user_roles
  defp authorized?(:role, role_id, %{id: user_id} = _user) do
    role_id
    |> Account.get_role_users()
    |> Enum.member?(user_id)
    |> case do
      true -> :ok
      _ -> {:error, :unauthorized}
    end
  end

  defp authorized?(_, _, _), do: {:error, :unauthorized}
end
