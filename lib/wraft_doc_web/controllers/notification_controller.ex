defmodule WraftDocWeb.Api.V1.NotificationController do
  use WraftDocWeb, :controller
  use PhoenixSwagger

  plug WraftDocWeb.Plug.AddActionLog

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.Notifications
  alias WraftDoc.Notifications.Notification
  alias WraftDoc.Notifications.Settings
  alias WraftDoc.Notifications.Template
  alias WraftDoc.Notifications.UserNotification

  def swagger_definitions do
    %{
      NotificationRequest:
        swagger_schema do
          title("Notification Request")
          description("Notification Request")

          properties do
            type(:string, "Type", required: true)
            message(:string, "Message", required: true)
            is_global(:boolean, "Is global")
            action(:map, "Action")
          end

          example(%{
            type: "reminder",
            message: "This is a sample notification message",
            is_global: false,
            action: %{
              label: "View Details",
              url: "/notifications/123"
            }
          })
        end,
      Notification:
        swagger_schema do
          title("Notification")
          description("Notification")

          properties do
            type(:string, "Type")
            message(:string, "Message")
            is_global(:boolean, "Is global")
            action_id(:string, "Action id")
            action(:map, "Action")
            inserted_at(:string, "Inserted at")
            updated_at(:string, "Updated at")
          end

          example(%{
            type: "reminder",
            message: "This is a sample notification message",
            is_global: false,
            inserted_at: "2023-02-20T14:30:00Z",
            updated_at: "2023-02-20T14:30:00Z",
            action: %{
              label: "View Details",
              url: "/notifications/123"
            }
          })
        end,
      UserNotification:
        swagger_schema do
          title("User Notification")
          description("User Notification")

          properties do
            id(:string, "id")
            recipient_id(:string, "Recipient id")
            actor_id(:string, "Actor id")
            status(:string, "Status")
            seen_at(:string, "Seen at")
            updated_at(:string, "Updated at")
            inserted_at(:string, "Inserted at")
            notification(Schema.ref(:Notification))
          end

          example(%{
            id: "78dee356-6d31-4a8d-8489-688bc369477c",
            organisation_id: "4085f5cf-752f-471f-a02e-156befae09f8e",
            recipient_id: "4085f5cf-752f-471f-a02e-156badas09f8e",
            status: "unread",
            seen_at: "2020-01-21T14:00:00Z",
            updated_at: "2020-01-21T14:00:00Z",
            inserted_at: "2020-02-21T14:00:00Z",
            notification: %{
              type: "reminder",
              message: "This is a sample notification message",
              is_global: false,
              action: %{
                label: "View Details",
                url: "/notifications/123"
              },
              actor_id: "4085f5cf-752f-471f-a02e-156badas09f8e",
              inserted_at: "2023-02-20T14:30:00Z",
              updated_at: "2023-02-20T14:30:00Z"
            }
          })
        end,
      NotificationIndexResponse:
        swagger_schema do
          properties do
            notifications(Schema.ref(:UserNotification))
            page_number(:integer, "Page number")
            total_pages(:integer, "Total number of pages")
            total_entries(:integer, "Total number of entries")
          end

          example(%{
            notifications: [
              %{
                id: "78dee356-6d31-4a8d-8489-688bc369477c",
                organisation_id: "4085f5cf-752f-471f-a02e-156befae09f8e",
                recipient_id: "4085f5cf-752f-471f-a02e-156badas09f8e",
                status: "unread",
                seen_at: "2020-01-21T14:00:00Z",
                updated_at: "2020-01-21T14:00:00Z",
                inserted_at: "2020-02-21T14:00:00Z",
                notification: %{
                  type: "reminder",
                  message: "This is a sample notification message",
                  is_global: false,
                  action: %{
                    label: "View Details",
                    url: "/notifications/123"
                  },
                  actor_id: "4085f5cf-752f-471f-a02e-156badas09f8e",
                  inserted_at: "2023-02-20T14:30:00Z",
                  updated_at: "2023-02-20T14:30:00Z"
                }
              }
            ],
            page_number: 1,
            total_pages: 1,
            total_entries: 1
          })
        end,
      NotificationSuccessResponse:
        swagger_schema do
          title("Notification Success Info")
          description("Response for notification read successfully")

          properties do
            info(:string, "Info")
          end

          example(%{
            info: "Success"
          })
        end,
      NotificationCountResponse:
        swagger_schema do
          title("Notification Count Info")
          description("Response for notification count")

          properties do
            count(:integer, "Count")
          end

          example(%{
            count: 1
          })
        end,
      NotificationSettingsResponse:
        swagger_schema do
          title("Notification Settings Info")
          description("Response for notification settings")

          properties do
            settings(:array, "Notification settings")
          end

          example([
            "pipeline.instance_failed",
            "pipeline.not_found",
            "pipeline.form_mapping_not_complete"
          ])
        end,
      NotificationEventsRequest:
        swagger_schema do
          title("Notification Events Request")
          description("Request body for updating notification settings")

          properties do
            events(:array, "List of notification events to enable", items: %{type: :string})
          end

          example(%{
            events: [
              "document.reminder",
              "document.add_comment",
              "document.pending_approvals",
              "document.state_update",
              "organisation.unassign_role",
              "organisation.assign_role",
              "organisation.join_organisation",
              "registration.user_joins_wraft"
            ]
          })
        end,
      NotificationEventsResponse:
        swagger_schema do
          title("Notification Events Info")
          description("Response for notification events")

          properties do
            events(:array, "Notification events")
          end

          example([
            %{
              description: "Get notified when documents require your approval or review",
              event: "document.pending_approvals"
            },
            %{
              description:
                "Stay updated when documents progress through approval workflow states",
              event: "document.state_update"
            }
          ])
        end
    }
  end

  swagger_path :create do
    post("/notifications")
    summary("create notification")

    parameters do
      notification(:body, Schema.ref(:NotificationRequest), "Notification to be created",
        required: true
      )
    end

    response(200, "Ok", Schema.ref(:Notification))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, params) do
    notification = Notifications.create_notification(conn.assigns.current_user.id, params)

    render(conn, "notification.json", notification: notification)
  end

  @doc """
  list notifications for a user within the organisation
  """
  swagger_path :index do
    get("/notifications")
    summary("List notifications")
    description("list notifications for a user within the organisation")

    response(200, "Ok", Schema.ref(:NotificationIndexResponse))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

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

  @doc """
  mark notification as read
  """
  swagger_path :read do
    put("/notifications/read/{id}")
    summary("mark notification as read")
    description("mark notification as read")

    parameters do
      id(:path, :string, "id", required: true)
    end

    response(200, "Ok", Schema.ref(:NotificationSuccessResponse))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec read(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def read(conn, %{"id" => id} = _params) do
    current_user = conn.assigns.current_user

    with %Notification{} = notification <-
           Notifications.get_notification(current_user, id),
         {:ok, %UserNotification{}} <- Notifications.read_notification(current_user, notification) do
      render(conn, "mark_as_read.json", info: "Notification marked as read")
    end
  end

  @doc """
  mark all notifications as read
  """
  swagger_path :read_all do
    put("/notifications/read_all")
    summary("mark all notifications as read")
    description("mark all notifications as read")
    response(200, "Ok", Schema.ref(:NotificationSuccessResponse))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

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

  @doc """
  count notifications
  """
  swagger_path :count do
    get("/notifications/count")
    summary("count notifications")
    description("count notifications")
    response(200, "Ok", Schema.ref(:NotificationCountResponse))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec count(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def count(conn, _params) do
    current_user = conn.assigns.current_user
    count = Notifications.unread_notification_count(current_user)
    render(conn, "count.json", count: count)
  end

  @doc """
  get settings
  """
  swagger_path :get_settings do
    get("/notifications/settings")
    summary("get settings")
    description("get settings")
    response(200, "Ok", Schema.ref(:NotificationSettingsResponse))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec get_settings(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def get_settings(conn, _params) do
    current_user = conn.assigns.current_user

    with %Settings{} = settings <- Notifications.get_organisation_settings(current_user) do
      render(conn, "settings.json", settings: settings)
    end
  end

  @doc """
  update settings
  """
  swagger_path :update_settings do
    put("/notifications/settings")
    summary("update settings")
    description("update settings")

    parameters do
      body(:body, Schema.ref(:NotificationEventsRequest), "Notification events request",
        required: true
      )
    end

    response(200, "Ok", Schema.ref(:NotificationSettingsResponse))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec update_settings(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update_settings(conn, params) do
    current_user = conn.assigns.current_user

    with {:ok, settings} <-
           Notifications.create_or_update_organisation_settings(current_user, params) do
      render(conn, "settings.json", settings: settings)
    end
  end

  @doc """
  get events
  """
  swagger_path :get_events do
    get("/notifications/events")
    summary("get events")
    description("get events")
    response(200, "Ok", Schema.ref(:NotificationEventsResponse))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec get_events(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def get_events(conn, _params) do
    render(conn, "events.json", events: Template.list_notifications())
  end
end
