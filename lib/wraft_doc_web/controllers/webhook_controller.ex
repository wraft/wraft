defmodule WraftDocWeb.Api.V1.WebhookController do
  use WraftDocWeb, :controller
  use OpenApiSpex.ControllerSpecs

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
  alias WraftDocWeb.Schemas.Error
  alias WraftDocWeb.Schemas.Webhook, as: WebhookSchema

  tags(["Webhooks"])

  operation(:create,
    summary: "Create webhook",
    description: "Create a new webhook for the organization",
    operation_id: "create_webhook",
    request_body: {"Webhook to create", "application/json", WebhookSchema.WebhookRequest},
    responses: [
      created: {"Created", "application/json", WebhookSchema.Webhook},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

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

  operation(:index,
    summary: "List webhooks",
    description: "List all webhooks for the organization",
    operation_id: "list_webhooks",
    parameters: [
      page: [in: :query, type: :integer, description: "Page number (default: 1)"],
      page_size: [in: :query, type: :integer, description: "Page size (default: 10)"]
    ],
    responses: [
      ok: {"OK", "application/json", WebhookSchema.WebhookIndex},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

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

  operation(:show,
    summary: "Get webhook",
    description: "Get a specific webhook by ID",
    operation_id: "get_webhook",
    parameters: [
      id: [in: :path, type: :string, description: "Webhook ID", required: true]
    ],
    responses: [
      ok: {"OK", "application/json", WebhookSchema.Webhook},
      not_found: {"Not Found", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

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

  operation(:update,
    summary: "Update webhook",
    description: "Update an existing webhook",
    operation_id: "update_webhook",
    parameters: [
      id: [in: :path, type: :string, description: "Webhook ID", required: true]
    ],
    request_body: {"Webhook updates", "application/json", WebhookSchema.WebhookRequest},
    responses: [
      ok: {"OK", "application/json", WebhookSchema.Webhook},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      not_found: {"Not Found", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

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

  operation(:delete,
    summary: "Delete webhook",
    description: "Delete a webhook",
    operation_id: "delete_webhook",
    parameters: [
      id: [in: :path, type: :string, description: "Webhook ID", required: true]
    ],
    responses: [
      no_content: {"No Content", "application/json", nil},
      not_found: {"Not Found", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

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

  operation(:toggle_status,
    summary: "Toggle webhook status",
    description: "Toggle webhook active/inactive status",
    operation_id: "toggle_webhook_status",
    parameters: [
      id: [in: :path, type: :string, description: "Webhook ID", required: true]
    ],
    responses: [
      ok: {"OK", "application/json", WebhookSchema.Webhook},
      not_found: {"Not Found", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

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

  operation(:events,
    summary: "Get available events",
    description: "Get list of available webhook events",
    operation_id: "get_webhook_events",
    responses: [
      ok: {"OK", "application/json", WebhookSchema.WebhookEvents},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  @spec events(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def events(conn, _params) do
    events = Webhooks.available_events()
    render(conn, "events.json", events: events)
  end

  operation(:test,
    summary: "Test webhook",
    description: "Send a test webhook request",
    operation_id: "test_webhook",
    parameters: [
      id: [in: :path, type: :string, description: "Webhook ID", required: true]
    ],
    request_body: {"Test request", "application/json", WebhookSchema.WebhookTestRequest},
    responses: [
      ok: {"OK", "application/json", nil},
      not_found: {"Not Found", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

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

  operation(:logs,
    summary: "Get webhook logs",
    description: "Get execution logs for a specific webhook",
    operation_id: "get_webhook_logs",
    parameters: [
      id: [in: :path, type: :string, description: "Webhook ID", required: true],
      page: [in: :query, type: :integer, description: "Page number (default: 1)"],
      page_size: [in: :query, type: :integer, description: "Page size (default: 10)"]
    ],
    responses: [
      ok: {"OK", "application/json", WebhookSchema.WebhookLogsIndex},
      not_found: {"Not Found", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

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

  operation(:all_logs,
    summary: "Get all webhook logs",
    description: "Get execution logs for all webhooks in the organization",
    operation_id: "get_all_webhook_logs",
    parameters: [
      page: [in: :query, type: :integer, description: "Page number (default: 1)"],
      page_size: [in: :query, type: :integer, description: "Page size (default: 10)"],
      webhook_id: [in: :query, type: :string, description: "Filter by webhook ID"],
      event: [in: :query, type: :string, description: "Filter by event"],
      success: [in: :query, type: :string, description: "Filter by success status (true/false)"],
      from_date: [in: :query, type: :string, description: "Filter from date (ISO 8601)"],
      to_date: [in: :query, type: :string, description: "Filter to date (ISO 8601)"]
    ],
    responses: [
      ok: {"OK", "application/json", WebhookSchema.WebhookLogsIndex},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

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

  operation(:log_details,
    summary: "Get webhook log details",
    description: "Get detailed information about a specific webhook execution",
    operation_id: "get_webhook_log_details",
    parameters: [
      log_id: [in: :path, type: :string, description: "Webhook log ID", required: true]
    ],
    responses: [
      ok: {"OK", "application/json", WebhookSchema.WebhookLog},
      not_found: {"Not Found", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

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

  operation(:stats,
    summary: "Get webhook statistics",
    description: "Get performance statistics for a webhook",
    operation_id: "get_webhook_stats",
    parameters: [
      id: [in: :path, type: :string, description: "Webhook ID", required: true]
    ],
    responses: [
      ok: {"OK", "application/json", WebhookSchema.WebhookStats},
      not_found: {"Not Found", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

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
