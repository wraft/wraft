defmodule WraftDocWeb.Api.V1.WebhookView do
  use WraftDocWeb, :view

  alias WraftDocWeb.Api.V1.{UserView, WebhookView}

  def render("index.json", %{
        webhooks: webhooks,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      }) do
    %{
      webhooks: render_many(webhooks, WebhookView, "webhook.json"),
      page_number: page_number,
      total_pages: total_pages,
      total_entries: total_entries
    }
  end

  def render("show.json", %{webhook: webhook}) do
    render_one(webhook, WebhookView, "webhook.json")
  end

  def render("webhook.json", %{webhook: webhook}) do
    %{
      id: webhook.id,
      name: webhook.name,
      url: webhook.url,
      events: webhook.events,
      is_active: webhook.is_active,
      headers: webhook.headers,
      retry_count: webhook.retry_count,
      timeout_seconds: webhook.timeout_seconds,
      last_triggered_at: webhook.last_triggered_at,
      last_response_status: webhook.last_response_status,
      failure_count: webhook.failure_count,
      creator: render_creator(webhook),
      inserted_at: webhook.inserted_at,
      updated_at: webhook.updated_at
    }
  end

  def render("events.json", %{events: events}) do
    %{events: events}
  end

  def render("logs.json", %{
        logs: logs,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      }) do
    %{
      logs: render_many(logs, WebhookView, "webhook_log.json", as: :log),
      page_number: page_number,
      total_pages: total_pages,
      total_entries: total_entries
    }
  end

  def render("log.json", %{log: log}) do
    render_one(log, WebhookView, "webhook_log_detailed.json", as: :log)
  end

  def render("webhook_log.json", %{log: log}) do
    %{
      id: log.id,
      event: log.event,
      url: log.url,
      http_method: log.http_method,
      response_status: log.response_status,
      execution_time_ms: log.execution_time_ms,
      success: log.success,
      error_message: log.error_message,
      attempt_number: log.attempt_number,
      triggered_at: log.triggered_at,
      webhook: render_webhook_info(log),
      inserted_at: log.inserted_at
    }
  end

  def render("webhook_log_detailed.json", %{log: log}) do
    %{
      id: log.id,
      event: log.event,
      url: log.url,
      http_method: log.http_method,
      request_headers: log.request_headers,
      request_body: log.request_body,
      response_status: log.response_status,
      response_headers: log.response_headers,
      response_body: log.response_body,
      execution_time_ms: log.execution_time_ms,
      success: log.success,
      error_message: log.error_message,
      attempt_number: log.attempt_number,
      triggered_at: log.triggered_at,
      webhook: render_webhook_info(log),
      inserted_at: log.inserted_at,
      updated_at: log.updated_at
    }
  end

  def render("stats.json", %{stats: stats}) do
    stats
  end

  defp render_creator(%{creator: %Ecto.Association.NotLoaded{}}), do: nil
  defp render_creator(%{creator: nil}), do: nil

  defp render_creator(%{creator: creator}) do
    render_one(creator, UserView, "user.json")
  end

  defp render_webhook_info(%{webhook: %Ecto.Association.NotLoaded{}}), do: nil
  defp render_webhook_info(%{webhook: nil}), do: nil

  defp render_webhook_info(%{webhook: webhook}) do
    %{
      id: webhook.id,
      name: webhook.name,
      url: webhook.url
    }
  end
end
