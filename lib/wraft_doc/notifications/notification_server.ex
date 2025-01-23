defmodule WraftDoc.Notifications.NotificationServer do
  @moduledoc """
  PubSub server for handling notification.
  """

  use GenServer
  require Logger

  alias Phoenix.PubSub
  alias WraftDoc.Notifications.Notification

  @pubsub WraftDoc.PubSub
  @notification_topic "user_notifications:"

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(init_arg) do
    {:ok, init_arg}
  end

  @doc """
  Subscribe the current process to user-specific notifications.
  """
  def subscribe(user_id) when is_binary(user_id) do
    PubSub.subscribe(@pubsub, notification_topic(user_id))
  rescue
    error ->
      Logger.error("Failed to subscribe to notifications: #{inspect(error)}")
      {:error, :subscription_failed}
  end

  @doc """
  Unsubscribe from user-specific notifications.
  """
  def unsubscribe(user_id) do
    PubSub.unsubscribe(@pubsub, notification_topic(user_id))
  rescue
    error ->
      Logger.error("Failed to unsubscribe from notifications: #{inspect(error)}")
      {:error, :unsubscribe_failed}
  end

  @doc """
  Broadcast a notification to a specific user.
  """
  def broadcast_notification(%Notification{} = notification, recipient) do
    with {:ok, message} <- build_notification_message(notification) do
      PubSub.broadcast(
        @pubsub,
        notification_topic(recipient.id),
        {:new_notification, message}
      )
    end
  end

  @doc """
  Broadcast a notification update.
  """

  def broadcast_notification_update(%Notification{} = notification, recipient) do
    with {:ok, message} <- build_notification_message(notification) do
      PubSub.broadcast(
        @pubsub,
        notification_topic(recipient.id),
        {:notification_updated, message}
      )
    end
  end

  @doc """
  Broadcast when all notifications are marked as read.
  """

  def broadcast_all_read(user_id) do
    PubSub.broadcast(
      @pubsub,
      notification_topic(user_id),
      {:all_notifications_read, %{timestamp: DateTime.utc_now()}}
    )
  end

  defp notification_topic(user_id) do
    @notification_topic <> to_string(user_id)
  end

  defp build_notification_message(notification) do
    message = WraftDoc.Notifications.get_notification_message(notification)
    {:ok, message}
  rescue
    error ->
      Logger.error("Failed to build notification message: #{inspect(error)}")
      {:error, :message_build_failed}
  end
end
