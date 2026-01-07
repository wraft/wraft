defmodule WraftDocWeb.Api.V1.NotificationController do
  use WraftDocWeb, :controller
  use OpenApiSpex.ControllerSpecs

  plug WraftDocWeb.Plug.AddActionLog

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.Notifications
  alias WraftDoc.Notifications.Notification
  alias WraftDoc.Notifications.Settings
  alias WraftDoc.Notifications.Template
  alias WraftDoc.Notifications.UserNotification
  alias WraftDocWeb.Schemas.Error
  alias WraftDocWeb.Schemas.Notification, as: NotificationSchema

  tags(["Notifications"])

  operation(:create,
    summary: "create notification",
    request_body:
      {"Notification to be created", "application/json", NotificationSchema.NotificationRequest},
    responses: [
      ok: {"Ok", "application/json", NotificationSchema.Notification},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, params) do
    notification = Notifications.create_notification(conn.assigns.current_user.id, params)

    render(conn, "notification.json", notification: notification)
  end

  operation(:index,
    summary: "List notifications",
    description: "list notifications for a user within the organisation",
    responses: [
      ok: {"Ok", "application/json", NotificationSchema.NotificationIndexResponse},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, params) do
    current_user = conn.assigns.current_user

    with %{
           entries: notifications,
           page_number: page_number,
           total_pages: total_pages,
           total_entries: total_entries
         } <- Notifications.list_notifications(current_user, params) do
      render(conn, "index.json",
        notifications: notifications,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      )
    end
  end

  operation(:read,
    summary: "mark notification as read",
    description: "mark notification as read",
    parameters: [
      id: [in: :path, type: :string, description: "id", required: true]
    ],
    responses: [
      ok: {"Ok", "application/json", NotificationSchema.NotificationSuccessResponse},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  @spec read(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def read(conn, %{"id" => id} = _params) do
    current_user = conn.assigns.current_user

    with %Notification{} = notification <-
           Notifications.get_notification(current_user, id),
         {:ok, %UserNotification{}} <- Notifications.read_notification(current_user, notification) do
      render(conn, "mark_as_read.json", info: "Notification marked as read")
    end
  end

  operation(:read_all,
    summary: "mark all notifications as read",
    description: "mark all notifications as read",
    responses: [
      ok: {"Ok", "application/json", NotificationSchema.NotificationSuccessResponse},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  @spec read_all(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def read_all(conn, _params) do
    conn.assigns.current_user
    |> Notifications.read_all_notifications()
    |> case do
      {0, nil} ->
        render(conn, "mark_as_read.json", info: "No notifications found")

      {count, nil} ->
        render(conn, "mark_as_read.json", info: "#{count} notifications marked as read")
    end
  end

  operation(:count,
    summary: "count notifications",
    description: "count notifications",
    responses: [
      ok: {"Ok", "application/json", NotificationSchema.NotificationCountResponse},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  @spec count(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def count(conn, _params) do
    current_user = conn.assigns.current_user
    count = Notifications.unread_notification_count(current_user)
    render(conn, "count.json", count: count)
  end

  operation(:get_settings,
    summary: "get settings",
    description: "get settings",
    responses: [
      ok: {"Ok", "application/json", NotificationSchema.NotificationSettingsResponse},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  @spec get_settings(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def get_settings(conn, _params) do
    current_user = conn.assigns.current_user

    with %Settings{} = settings <- Notifications.get_organisation_settings(current_user) do
      render(conn, "settings.json", settings: settings)
    end
  end

  operation(:update_settings,
    summary: "update settings",
    description: "update settings",
    request_body:
      {"Notification events request", "application/json",
       NotificationSchema.NotificationEventsRequest},
    responses: [
      ok: {"Ok", "application/json", NotificationSchema.NotificationSettingsResponse},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  @spec update_settings(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update_settings(conn, params) do
    current_user = conn.assigns.current_user

    with {:ok, settings} <-
           Notifications.create_or_update_organisation_settings(current_user, params) do
      render(conn, "settings.json", settings: settings)
    end
  end

  operation(:get_events,
    summary: "get events",
    description: "get events",
    responses: [
      ok: {"Ok", "application/json", NotificationSchema.NotificationEventsResponse},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  @spec get_events(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def get_events(conn, _params) do
    render(conn, "events.json", events: Template.list_notifications())
  end
end
