defmodule WraftDocWeb.Schemas.Webhook do
  @moduledoc """
  Schema for Webhook request and response
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

  defmodule WebhookRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Webhook Request",
      description: "Create or update webhook",
      type: :object,
      properties: %{
        name: %Schema{type: :string, description: "Name of the webhook"},
        url: %Schema{type: :string, description: "URL to send webhook requests"},
        secret: %Schema{type: :string, description: "Secret for webhook signature verification"},
        events: %Schema{
          type: :array,
          description: "List of events to trigger webhook",
          items: %Schema{type: :string}
        },
        is_active: %Schema{
          type: :boolean,
          description: "Whether webhook is active",
          default: true
        },
        headers: %Schema{type: :object, description: "Custom headers to send with webhook"},
        retry_count: %Schema{type: :integer, description: "Number of retry attempts", default: 3},
        timeout_seconds: %Schema{
          type: :integer,
          description: "Request timeout in seconds",
          default: 30
        }
      },
      required: [:name, :url, :events],
      example: %{
        name: "My Document Webhook",
        url: "https://api.example.com/webhooks/documents",
        secret: "my-secret-key",
        events: ["document.created", "document.signed"],
        is_active: true,
        headers: %{"Authorization" => "Bearer token123"},
        retry_count: 3,
        timeout_seconds: 30
      }
    })
  end

  defmodule Webhook do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Webhook",
      description: "Webhook response",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "ID of the webhook"},
        name: %Schema{type: :string, description: "Name of the webhook"},
        url: %Schema{type: :string, description: "URL to send webhook requests"},
        events: %Schema{
          type: :array,
          description: "List of events that trigger webhook",
          items: %Schema{type: :string}
        },
        is_active: %Schema{type: :boolean, description: "Whether webhook is active"},
        headers: %Schema{type: :object, description: "Custom headers to send with webhook"},
        retry_count: %Schema{type: :integer, description: "Number of retry attempts"},
        timeout_seconds: %Schema{type: :integer, description: "Request timeout in seconds"},
        last_triggered_at: %Schema{type: :string, description: "Last time webhook was triggered"},
        last_response_status: %Schema{type: :integer, description: "Last HTTP response status"},
        failure_count: %Schema{type: :integer, description: "Number of consecutive failures"},
        creator: WraftDocWeb.Schemas.User.User,
        inserted_at: %Schema{type: :string, description: "When webhook was created"},
        updated_at: %Schema{type: :string, description: "When webhook was last updated"}
      },
      example: %{
        id: "550e8400-e29b-41d4-a716-446655440000",
        name: "My Document Webhook",
        url: "https://api.example.com/webhooks/documents",
        events: ["document.created", "document.signed"],
        is_active: true,
        headers: %{"Authorization" => "Bearer token123"},
        retry_count: 3,
        timeout_seconds: 30,
        last_triggered_at: "2024-01-15T10:30:00Z",
        last_response_status: 200,
        failure_count: 0,
        inserted_at: "2024-01-15T10:00:00Z",
        updated_at: "2024-01-15T10:30:00Z"
      }
    })
  end

  defmodule WebhookIndex do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Webhook Index",
      description: "List of webhooks with pagination",
      type: :object,
      properties: %{
        webhooks: %Schema{type: :array, description: "List of webhooks", items: Webhook},
        page_number: %Schema{type: :integer, description: "Current page number"},
        total_pages: %Schema{type: :integer, description: "Total number of pages"},
        total_entries: %Schema{type: :integer, description: "Total number of webhooks"}
      }
    })
  end

  defmodule WebhookEvents do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Available Webhook Events",
      description: "List of available webhook events",
      type: :object,
      properties: %{
        events: %Schema{
          type: :array,
          description: "Available webhook events",
          items: %Schema{type: :string}
        }
      },
      example: %{
        events: [
          "document.created",
          "document.sent",
          "document.completed",
          "document.cancelled",
          "document.signed",
          "document.rejected"
        ]
      }
    })
  end

  defmodule WebhookTestRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Webhook Test Request",
      description: "Test webhook request",
      type: :object,
      properties: %{
        event: %Schema{type: :string, description: "Event to test"},
        test_data: %Schema{type: :object, description: "Test payload data"}
      },
      required: [:event],
      example: %{
        event: "document.created",
        test_data: %{
          document_id: "550e8400-e29b-41d4-a716-446655440000",
          title: "Test Document"
        }
      }
    })
  end

  defmodule WebhookLog do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Webhook Log",
      description: "Webhook execution log entry",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "Log entry ID"},
        event: %Schema{type: :string, description: "Event type"},
        url: %Schema{type: :string, description: "Webhook URL"},
        http_method: %Schema{type: :string, description: "HTTP method"},
        request_headers: %Schema{type: :object, description: "Request headers"},
        request_body: %Schema{type: :string, description: "Request body"},
        response_status: %Schema{type: :integer, description: "HTTP response status"},
        response_headers: %Schema{type: :object, description: "Response headers"},
        response_body: %Schema{type: :string, description: "Response body"},
        execution_time_ms: %Schema{type: :integer, description: "Execution time in milliseconds"},
        success: %Schema{type: :boolean, description: "Whether execution was successful"},
        error_message: %Schema{type: :string, description: "Error message if failed"},
        attempt_number: %Schema{type: :integer, description: "Attempt number"},
        triggered_at: %Schema{type: :string, description: "When webhook was triggered"},
        webhook: Webhook,
        inserted_at: %Schema{type: :string, description: "When log was created"}
      }
    })
  end

  defmodule WebhookLogsIndex do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Webhook Logs Index",
      description: "List of webhook logs with pagination",
      type: :object,
      properties: %{
        logs: %Schema{type: :array, description: "List of webhook logs", items: WebhookLog},
        page_number: %Schema{type: :integer, description: "Current page number"},
        total_pages: %Schema{type: :integer, description: "Total number of pages"},
        total_entries: %Schema{type: :integer, description: "Total number of logs"}
      }
    })
  end

  defmodule WebhookStats do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Webhook Statistics",
      description: "Webhook performance statistics",
      type: :object,
      properties: %{
        total_requests: %Schema{type: :integer, description: "Total number of requests"},
        successful_requests: %Schema{type: :integer, description: "Number of successful requests"},
        failed_requests: %Schema{type: :integer, description: "Number of failed requests"},
        success_rate: %Schema{type: :number, description: "Success rate percentage"},
        average_response_time_ms: %Schema{
          type: :number,
          description: "Average response time in milliseconds"
        },
        period_days: %Schema{type: :integer, description: "Statistics period in days"}
      },
      example: %{
        total_requests: 150,
        successful_requests: 145,
        failed_requests: 5,
        success_rate: 96.67,
        average_response_time_ms: 245.5,
        period_days: 30
      }
    })
  end
end
