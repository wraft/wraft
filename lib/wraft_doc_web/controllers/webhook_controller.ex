defmodule WraftDocWeb.Api.V1.WebhookController do
  use WraftDocWeb, :controller
  use PhoenixSwagger

  plug WraftDocWeb.Plug.AddActionLog

  plug WraftDocWeb.Plug.Authorized,
    create: "webhook:manage",
    index: "webhook:show",
    show: "webhook:show",
    update: "webhook:manage",
    delete: "webhook:delete",
    toggle_status: "webhook:manage",
    test: "webhook:manage"

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.Webhooks
  alias WraftDoc.Webhooks.Webhook

  def swagger_definitions do
    %{
      WebhookRequest:
        swagger_schema do
          title("Webhook Request")
          description("Create or update webhook")

          properties do
            name(:string, "Name of the webhook", required: true)
            url(:string, "URL to send webhook requests", required: true)
            secret(:string, "Secret for webhook signature verification")
            events(:array, "List of events to trigger webhook", required: true)
            is_active(:boolean, "Whether webhook is active", default: true)
            headers(:object, "Custom headers to send with webhook")
            retry_count(:integer, "Number of retry attempts", default: 3)
            timeout_seconds(:integer, "Request timeout in seconds", default: 30)
          end

          example(%{
            name: "My Document Webhook",
            url: "https://api.example.com/webhooks/documents",
            secret: "my-secret-key",
            events: ["document.created", "document.signed"],
            is_active: true,
            headers: %{"Authorization" => "Bearer token123"},
            retry_count: 3,
            timeout_seconds: 30
          })
        end,
      Webhook:
        swagger_schema do
          title("Webhook")
          description("Webhook response")

          properties do
            id(:string, "ID of the webhook")
            name(:string, "Name of the webhook")
            url(:string, "URL to send webhook requests")
            events(:array, "List of events that trigger webhook")
            is_active(:boolean, "Whether webhook is active")
            headers(:object, "Custom headers to send with webhook")
            retry_count(:integer, "Number of retry attempts")
            timeout_seconds(:integer, "Request timeout in seconds")
            last_triggered_at(:string, "Last time webhook was triggered")
            last_response_status(:integer, "Last HTTP response status")
            failure_count(:integer, "Number of consecutive failures")
            creator(Schema.ref(:User))
            inserted_at(:string, "When webhook was created")
            updated_at(:string, "When webhook was last updated")
          end

          example(%{
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
          })
        end,
      WebhookIndex:
        swagger_schema do
          title("Webhook Index")
          description("List of webhooks with pagination")

          properties do
            webhooks(:array, "List of webhooks", items: Schema.ref(:Webhook))
            page_number(:integer, "Current page number")
            total_pages(:integer, "Total number of pages")
            total_entries(:integer, "Total number of webhooks")
          end
        end,
      WebhookEvents:
        swagger_schema do
          title("Available Webhook Events")
          description("List of available webhook events")

          properties do
            events(:array, "Available webhook events")
          end

          example(%{
            events: [
              "document.created",
              "document.sent",
              "document.completed",
              "document.cancelled",
              "document.signed",
              "document.rejected"
            ]
          })
        end,
      WebhookTestRequest:
        swagger_schema do
          title("Webhook Test Request")
          description("Test webhook request")

          properties do
            event(:string, "Event to test", required: true)
            test_data(:object, "Test payload data")
          end

          example(%{
            event: "document.created",
            test_data: %{
              document_id: "550e8400-e29b-41d4-a716-446655440000",
              title: "Test Document"
            }
          })
        end,
      WebhookLog:
        swagger_schema do
          title("Webhook Log")
          description("Webhook execution log entry")

          properties do
            id(:string, "Log entry ID")
            event(:string, "Event type")
            url(:string, "Webhook URL")
            http_method(:string, "HTTP method")
            request_headers(:object, "Request headers")
            request_body(:string, "Request body")
            response_status(:integer, "HTTP response status")
            response_headers(:object, "Response headers")
            response_body(:string, "Response body")
            execution_time_ms(:integer, "Execution time in milliseconds")
            success(:boolean, "Whether execution was successful")
            error_message(:string, "Error message if failed")
            attempt_number(:integer, "Attempt number")
            triggered_at(:string, "When webhook was triggered")
            webhook(Schema.ref(:Webhook))
            inserted_at(:string, "When log was created")
          end
        end,
      WebhookLogsIndex:
        swagger_schema do
          title("Webhook Logs Index")
          description("List of webhook logs with pagination")

          properties do
            logs(:array, "List of webhook logs", items: Schema.ref(:WebhookLog))
            page_number(:integer, "Current page number")
            total_pages(:integer, "Total number of pages")
            total_entries(:integer, "Total number of logs")
          end
        end,
      WebhookStats:
        swagger_schema do
          title("Webhook Statistics")
          description("Webhook performance statistics")

          properties do
            total_requests(:integer, "Total number of requests")
            successful_requests(:integer, "Number of successful requests")
            failed_requests(:integer, "Number of failed requests")
            success_rate(:number, "Success rate percentage")
            average_response_time_ms(:number, "Average response time in milliseconds")
            period_days(:integer, "Statistics period in days")
          end

          example(%{
            total_requests: 150,
            successful_requests: 145,
            failed_requests: 5,
            success_rate: 96.67,
            average_response_time_ms: 245.5,
            period_days: 30
          })
        end
    }
  end

  swagger_path :create do
    post("/webhooks")
    summary("Create webhook")
    description("Create a new webhook for the organization")
    operation_id("create_webhook")
    tag("Webhooks")

    parameters do
      webhook(:body, Schema.ref(:WebhookRequest), "Webhook to create", required: true)
    end

    response(201, "Created", Schema.ref(:Webhook))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, params) do
    current_user = conn.assigns.current_user

    with {:ok, webhook} <- Webhooks.create_webhook(current_user, params) do
      webhook = WraftDoc.Repo.preload(webhook, :creator)

      conn
      |> put_status(:created)
      |> render("show.json", webhook: webhook)
    end
  end

  swagger_path :index do
    get("/webhooks")
    summary("List webhooks")
    description("List all webhooks for the organization")
    operation_id("list_webhooks")
    tag("Webhooks")

    parameters do
      page(:query, :integer, "Page number", default: 1)
      page_size(:query, :integer, "Page size", default: 10)
    end

    response(200, "OK", Schema.ref(:WebhookIndex))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, params) do
    current_user = conn.assigns.current_user

    %{
      entries: webhooks,
      page_number: page_number,
      total_pages: total_pages,
      total_entries: total_entries
    } = Webhooks.list_webhooks(current_user, params)

    render(conn, "index.json",
      webhooks: webhooks,
      page_number: page_number,
      total_pages: total_pages,
      total_entries: total_entries
    )
  end

  swagger_path :show do
    get("/webhooks/{id}")
    summary("Get webhook")
    description("Get a specific webhook by ID")
    operation_id("get_webhook")
    tag("Webhooks")

    parameters do
      id(:path, :string, "Webhook ID", required: true)
    end

    response(200, "OK", Schema.ref(:Webhook))
    response(404, "Not Found", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user

    case Webhooks.get_webhook(current_user, id) do
      %Webhook{} = webhook ->
        webhook = WraftDoc.Repo.preload(webhook, :creator)
        render(conn, "show.json", webhook: webhook)

      nil ->
        {:error, :not_found}
    end
  end

  swagger_path :update do
    put("/webhooks/{id}")
    summary("Update webhook")
    description("Update an existing webhook")
    operation_id("update_webhook")
    tag("Webhooks")

    parameters do
      id(:path, :string, "Webhook ID", required: true)
      webhook(:body, Schema.ref(:WebhookRequest), "Webhook updates", required: true)
    end

    response(200, "OK", Schema.ref(:Webhook))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(404, "Not Found", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec update(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update(conn, %{"id" => id} = params) do
    current_user = conn.assigns.current_user

    with %Webhook{} = webhook <- Webhooks.get_webhook(current_user, id),
         {:ok, updated_webhook} <- Webhooks.update_webhook(webhook, params) do
      updated_webhook = WraftDoc.Repo.preload(updated_webhook, :creator)
      render(conn, "show.json", webhook: updated_webhook)
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  swagger_path :delete do
    PhoenixSwagger.Path.delete("/webhooks/{id}")
    summary("Delete webhook")
    description("Delete a webhook")
    operation_id("delete_webhook")
    tag("Webhooks")

    parameters do
      id(:path, :string, "Webhook ID", required: true)
    end

    response(204, "No Content")
    response(404, "Not Found", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec delete(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def delete(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user

    with %Webhook{} = webhook <- Webhooks.get_webhook(current_user, id),
         {:ok, _} <- Webhooks.delete_webhook(webhook) do
      send_resp(conn, :no_content, "")
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  swagger_path :toggle_status do
    patch("/webhooks/{id}/toggle")
    summary("Toggle webhook status")
    description("Toggle webhook active/inactive status")
    operation_id("toggle_webhook_status")
    tag("Webhooks")

    parameters do
      id(:path, :string, "Webhook ID", required: true)
    end

    response(200, "OK", Schema.ref(:Webhook))
    response(404, "Not Found", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec toggle_status(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def toggle_status(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user

    with %Webhook{} = webhook <- Webhooks.get_webhook(current_user, id),
         {:ok, updated_webhook} <- Webhooks.toggle_webhook_status(webhook) do
      updated_webhook = WraftDoc.Repo.preload(updated_webhook, :creator)
      render(conn, "show.json", webhook: updated_webhook)
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  swagger_path :events do
    get("/webhooks/events")
    summary("Get available events")
    description("Get list of available webhook events")
    operation_id("get_webhook_events")
    tag("Webhooks")

    response(200, "OK", Schema.ref(:WebhookEvents))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec events(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def events(conn, _params) do
    events = Webhooks.available_events()
    render(conn, "events.json", events: events)
  end

  swagger_path :test do
    post("/webhooks/{id}/test")
    summary("Test webhook")
    description("Send a test webhook request")
    operation_id("test_webhook")
    tag("Webhooks")

    parameters do
      id(:path, :string, "Webhook ID", required: true)
      test_request(:body, Schema.ref(:WebhookTestRequest), "Test request", required: true)
    end

    response(200, "OK")
    response(404, "Not Found", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec test(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def test(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user

    # Get event and content from request body
    event = Map.get(conn.body_params, "event", "test")
    content = Map.get(conn.body_params, "content", "This is a test webhook message from WraftDoc")
    timestamp = DateTime.to_iso8601(DateTime.utc_now())

    case Webhooks.get_webhook(current_user, id) do
      %Webhook{} = _webhook ->
        # Build comprehensive test data
        test_data = %{
          event: event,
          content: content,
          organization: current_user.current_org_id,
          user: current_user.name || current_user.email,
          document_id: "test-doc-123",
          timestamp: timestamp,
          test: true,
          triggered_by: "webhook_test",
          webhook_id: id
        }

        # Trigger the webhook with test data
        Webhooks.trigger_webhooks(event, current_user.current_org_id, test_data)

        json(conn, %{message: "Test webhook triggered successfully"})

      nil ->
        {:error, :not_found}
    end
  end

  swagger_path :logs do
    get("/webhooks/{id}/logs")
    summary("Get webhook logs")
    description("Get execution logs for a specific webhook")
    operation_id("get_webhook_logs")
    tag("Webhooks")

    parameters do
      id(:path, :string, "Webhook ID", required: true)
      page(:query, :integer, "Page number", default: 1)
      page_size(:query, :integer, "Page size", default: 10)
    end

    response(200, "OK", Schema.ref(:WebhookLogsIndex))
    response(404, "Not Found", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec logs(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def logs(conn, %{"id" => id} = params) do
    current_user = conn.assigns.current_user

    case Webhooks.get_webhook(current_user, id) do
      %Webhook{} = _webhook ->
        %{
          entries: logs,
          page_number: page_number,
          total_pages: total_pages,
          total_entries: total_entries
        } = Webhooks.list_webhook_logs(current_user, id, params)

        render(conn, "logs.json",
          logs: logs,
          page_number: page_number,
          total_pages: total_pages,
          total_entries: total_entries
        )

      nil ->
        {:error, :not_found}
    end
  end

  swagger_path :all_logs do
    get("/webhooks/logs")
    summary("Get all webhook logs")
    description("Get execution logs for all webhooks in the organization")
    operation_id("get_all_webhook_logs")
    tag("Webhooks")

    parameters do
      page(:query, :integer, "Page number", default: 1)
      page_size(:query, :integer, "Page size", default: 10)
      webhook_id(:query, :string, "Filter by webhook ID")
      event(:query, :string, "Filter by event")
      success(:query, :string, "Filter by success status (true/false)")
      from_date(:query, :string, "Filter from date (ISO 8601)")
      to_date(:query, :string, "Filter to date (ISO 8601)")
    end

    response(200, "OK", Schema.ref(:WebhookLogsIndex))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec all_logs(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def all_logs(conn, params) do
    current_user = conn.assigns.current_user

    %{
      entries: logs,
      page_number: page_number,
      total_pages: total_pages,
      total_entries: total_entries
    } = Webhooks.list_all_webhook_logs(current_user, params)

    render(conn, "logs.json",
      logs: logs,
      page_number: page_number,
      total_pages: total_pages,
      total_entries: total_entries
    )
  end

  swagger_path :log_details do
    get("/webhooks/logs/{log_id}")
    summary("Get webhook log details")
    description("Get detailed information about a specific webhook execution")
    operation_id("get_webhook_log_details")
    tag("Webhooks")

    parameters do
      log_id(:path, :string, "Webhook log ID", required: true)
    end

    response(200, "OK", Schema.ref(:WebhookLog))
    response(404, "Not Found", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec log_details(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def log_details(conn, %{"log_id" => log_id}) do
    current_user = conn.assigns.current_user

    case Webhooks.get_webhook_log(current_user, log_id) do
      log when not is_nil(log) ->
        render(conn, "log.json", log: log)

      nil ->
        {:error, :not_found}
    end
  end

  swagger_path :stats do
    get("/webhooks/{id}/stats")
    summary("Get webhook statistics")
    description("Get performance statistics for a webhook")
    operation_id("get_webhook_stats")
    tag("Webhooks")

    parameters do
      id(:path, :string, "Webhook ID", required: true)
    end

    response(200, "OK", Schema.ref(:WebhookStats))
    response(404, "Not Found", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  @spec stats(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def stats(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user

    case Webhooks.get_webhook(current_user, id) do
      %Webhook{} = _webhook ->
        stats = Webhooks.get_webhook_stats(current_user, id)
        render(conn, "stats.json", stats: stats)

      nil ->
        {:error, :not_found}
    end
  end
end
