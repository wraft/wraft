defmodule WraftDocWeb.Schemas.Notification do
  @moduledoc """
  Schema for Notification request and response
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

  defmodule NotificationRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Notification Request",
      description: "Notification Request",
      type: :object,
      properties: %{
        type: %Schema{type: :string, description: "Type"},
        message: %Schema{type: :string, description: "Message"},
        is_global: %Schema{type: :boolean, description: "Is global"},
        action: %Schema{type: :object, description: "Action"}
      },
      required: [:type, :message],
      example: %{
        type: "reminder",
        message: "This is a sample notification message",
        is_global: false,
        action: %{
          label: "View Details",
          url: "/notifications/123"
        }
      }
    })
  end

  defmodule Notification do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Notification",
      description: "Notification",
      type: :object,
      properties: %{
        type: %Schema{type: :string, description: "Type"},
        message: %Schema{type: :string, description: "Message"},
        is_global: %Schema{type: :boolean, description: "Is global"},
        action_id: %Schema{type: :string, description: "Action id"},
        action: %Schema{type: :object, description: "Action"},
        inserted_at: %Schema{type: :string, description: "Inserted at"},
        updated_at: %Schema{type: :string, description: "Updated at"}
      },
      example: %{
        type: "reminder",
        message: "This is a sample notification message",
        is_global: false,
        inserted_at: "2023-02-20T14:30:00Z",
        updated_at: "2023-02-20T14:30:00Z",
        action: %{
          label: "View Details",
          url: "/notifications/123"
        }
      }
    })
  end

  defmodule UserNotification do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "User Notification",
      description: "User Notification",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "id"},
        recipient_id: %Schema{type: :string, description: "Recipient id"},
        actor_id: %Schema{type: :string, description: "Actor id"},
        status: %Schema{type: :string, description: "Status"},
        seen_at: %Schema{type: :string, description: "Seen at"},
        updated_at: %Schema{type: :string, description: "Updated at"},
        inserted_at: %Schema{type: :string, description: "Inserted at"},
        notification: Notification
      },
      example: %{
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
    })
  end

  defmodule NotificationIndexResponse do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Notification Index Response",
      type: :object,
      properties: %{
        notifications: %Schema{type: :array, items: UserNotification},
        page_number: %Schema{type: :integer, description: "Page number"},
        total_pages: %Schema{type: :integer, description: "Total number of pages"},
        total_entries: %Schema{type: :integer, description: "Total number of entries"}
      },
      example: %{
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
      }
    })
  end

  defmodule NotificationSuccessResponse do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Notification Success Info",
      description: "Response for notification read successfully",
      type: :object,
      properties: %{
        info: %Schema{type: :string, description: "Info"}
      },
      example: %{
        info: "Success"
      }
    })
  end

  defmodule NotificationCountResponse do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Notification Count Info",
      description: "Response for notification count",
      type: :object,
      properties: %{
        count: %Schema{type: :integer, description: "Count"}
      },
      example: %{
        count: 1
      }
    })
  end

  defmodule NotificationSettingsResponse do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Notification Settings Info",
      description: "Response for notification settings",
      type: :object,
      properties: %{
        settings: %Schema{
          type: :array,
          description: "Notification settings",
          items: %Schema{type: :string}
        }
      },
      example: %{
        settings: [
          "pipeline.instance_failed",
          "pipeline.not_found",
          "pipeline.form_mapping_not_complete"
        ]
      }
    })
  end

  defmodule NotificationEventsRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Notification Events Request",
      description: "Request body for updating notification settings",
      type: :object,
      properties: %{
        events: %Schema{
          type: :array,
          description: "List of notification events to enable",
          items: %Schema{type: :string}
        }
      },
      example: %{
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
      }
    })
  end

  defmodule NotificationEventsResponse do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Notification Events Info",
      description: "Response for notification events",
      type: :object,
      properties: %{
        events: %Schema{
          type: :array,
          description: "Notification events",
          items: %Schema{
            type: :object,
            properties: %{
              description: %Schema{type: :string, description: "Event description"},
              event: %Schema{type: :string, description: "Event name"}
            }
          }
        }
      },
      example: %{
        events: [
          %{
            description: "Get notified when documents require your approval or review",
            event: "document.pending_approvals"
          },
          %{
            description: "Stay updated when documents progress through approval workflow states",
            event: "document.state_update"
          }
        ]
      }
    })
  end
end
