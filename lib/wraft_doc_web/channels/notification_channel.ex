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

  def join("user_notification:" <> user_id, _payload, socket) do
    if authorized?(user_id, socket.assigns.current_user) do
      {:ok, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  def join("organisation_notification:" <> organisation_id, _payload, socket) do
    if authorized?(organisation_id, socket.assigns.current_user) do
      {:ok, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  @spec broad_cast(String.t(), String.t(), atom(), User.t()) :: {:noreply, Phoenix.Socket.t()}
  def broad_cast(message, event, scope, user) do
    socket = create_socket(scope, user)
    broadcast!(socket, event, %{body: message})
    {:noreply, socket}
  end

  defp create_socket(scope, current_user) do
    socket = build_socket_params(scope, current_user)

    %Phoenix.Socket{}
    |> assign(:current_user, current_user)
    |> Map.merge(socket)
  end

  defp build_socket_params(scope, current_user) do
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
      topic: get_topic(scope, current_user),
      transport: Phoenix.Transports.WebSocket,
      transport_name: :websocket,
      vsn: "2.0.0"
    }
  end

  defp get_topic(:user, %{id: user_id} = _user), do: "user_notification:#{user_id}"

  defp get_topic(:organisation, %{current_org_id: organisation_id} = _user),
    do: "organisation_notification:#{organisation_id}"

  # TODO: remove this later.
  defp get_topic(_, %{id: user_id} = _user), do: "notification:#{user_id}"

  defp authorized?(user_id, %{id: current_user_id})
       when user_id == current_user_id,
       do: :ok

  defp authorized?(organisation_id, %{current_org_id: current_org_id})
       when organisation_id == current_org_id,
       do: :ok

  defp authorized?(_, _), do: {:error, :unauthorized}
end
