defmodule WraftDocWeb.Schemas.Reminder do
  @moduledoc """
  Schema for Reminder request and response
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

  defmodule ReminderRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Reminder Request",
      description: "A reminder to be created or updated for a contract",
      type: :object,
      properties: %{
        reminder_date: %Schema{
          type: :string,
          description: "Date when reminder should be triggered",
          format: "date"
        },
        message: %Schema{type: :string, description: "Reminder message content"},
        notification_type: %Schema{
          type: :string,
          description: "Type of notification to send: 'email', 'in_app', or 'both'"
        },
        recipients: %Schema{
          type: :array,
          description: "List of recipient user IDs",
          items: %Schema{type: :string}
        },
        manual_date: %Schema{
          type: :boolean,
          description: "Whether this is a manually scheduled reminder"
        }
      },
      required: [:reminder_date, :message, :notification_type],
      example: %{
        reminder_date: "2023-12-31",
        message: "Contract renewal due soon",
        notification_type: "both",
        recipients: ["user-123", "user-456"],
        manual_date: true
      }
    })
  end

  defmodule Reminder do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Reminder",
      description: "A contract reminder",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "Reminder UUID", format: "uuid"},
        content_id: %Schema{type: :string, description: "Document ID", format: "uuid"},
        reminder_date: %Schema{
          type: :string,
          description: "Date when reminder should be triggered",
          format: "date"
        },
        status: %Schema{
          type: :string,
          description: "Current status of the reminder: 'pending' or 'sent'"
        },
        message: %Schema{type: :string, description: "Reminder message content"},
        notification_type: %Schema{
          type: :string,
          description: "Type of notification to send: 'email', 'in_app', or 'both'"
        },
        recipients: %Schema{
          type: :array,
          description: "List of recipient user IDs",
          items: %Schema{type: :string}
        },
        manual_date: %Schema{
          type: :boolean,
          description: "Whether this is a manually scheduled reminder"
        },
        sent_at: %Schema{
          type: :string,
          description: "When the reminder was sent",
          format: "ISO-8601"
        },
        inserted_at: %Schema{
          type: :string,
          description: "When the reminder was created",
          format: "ISO-8601"
        },
        updated_at: %Schema{
          type: :string,
          description: "When the reminder was last updated",
          format: "ISO-8601"
        }
      },
      example: %{
        id: "2a4d5c6f-8e9f-4a1b-8c5d-9e7f4a3b2c1d",
        content_id: "3b2a1d4c-5e6f-7a8b-9c1d-2e3f4a5b6c7d",
        reminder_date: "2023-12-31",
        status: "pending",
        message: "Contract renewal due soon",
        notification_type: "both",
        recipients: [
          "238ed26a-a06d-4305-b01b-6959500e3606",
          "bc3c3a7f-ffce-475a-be7c-e034cca94b09"
        ],
        manual_date: true,
        sent_at: nil,
        inserted_at: "2023-06-15T14:00:00Z",
        updated_at: "2023-06-15T14:00:00Z"
      }
    })
  end

  defmodule ReminderIndex do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Reminder Index",
      type: :object,
      properties: %{
        reminders: %Schema{type: :array, items: Reminder},
        page_number: %Schema{type: :integer, description: "Page number"},
        total_pages: %Schema{type: :integer, description: "Total number of pages"},
        total_entries: %Schema{type: :integer, description: "Total number of entries"}
      }
    })
  end
end
