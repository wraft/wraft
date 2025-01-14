defmodule WraftDocWeb.Api.V1.NotificationController do
  use WraftDocWeb, :controller
  use PhoenixSwagger

  plug WraftDocWeb.Plug.AddActionLog

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.Notifications
  alias WraftDoc.Notifications.UserNotifications

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, params) do
    current_user = conn.assigns.current_user
    notification = Notifications.create_notification(current_user, params)

    render(conn, "notification.json", notification: notification)
  end

  @doc """
  list notifications for a user within the organisation
  """

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, params) do
    current_user = conn.assigns.current_user

    with %{
           entries: notifications,
           page_number: page_number,
           total_pages: total_pages,
           total_entries: total_entries
         } <- Notifications.list_unread_notifications(current_user, params) do
      render(conn, "index.json",
        notifications: notifications,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      )
    end
  end

  @doc """
  mark notification as read
  """

  @spec read(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def read(conn, %{"id" => id} = _params) do
    current_user = conn.assigns.current_user

    with %UserNotifications{} = user_notification <-
           Notifications.get_user_notification(current_user, id),
         %UserNotifications{} <- Notifications.read_notification(user_notification) do
      render(conn, "mark_as_read.json", info: "Notification marked as read")
    end
  end

  @doc """
  mark all notifications as read
  """
  @spec read_all(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def read_all(conn, _params) do
    current_user = conn.assigns.current_user

    case Notifications.read_all_notifications(current_user) do
      {0, nil} ->
        render(conn, "mark_as_read.json", info: "No notifications found")

      {count, nil} ->
        render(conn, "mark_as_read.json", info: "#{count} notifications marked as read")
    end
  end

  @doc """
  count notifications
  """

  @spec count(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def count(conn, _params) do
    current_user = conn.assigns.current_user
    count = Notifications.unread_notification_count(current_user)
    render(conn, "count.json", count: count)
  end
end
