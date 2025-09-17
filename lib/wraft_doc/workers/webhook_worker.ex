defmodule WraftDoc.Workers.WebhookWorker do
  @moduledoc """
  Oban worker for processing webhook triggers.
  """
  use Oban.Worker, queue: :webhooks, max_attempts: 5
  require Logger

  alias WraftDoc.Repo
  alias WraftDoc.Webhooks
  alias WraftDoc.Webhooks.Webhook

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{
          "webhook_id" => webhook_id,
          "event" => event,
          "payload" => payload,
          "attempt" => attempt
        }
      }) do
    Logger.info("Processing webhook trigger #{webhook_id} event #{event} attempt #{attempt}")

    case Repo.get(Webhook, webhook_id) do
      nil ->
        Logger.error("Webhook not found #{webhook_id}")
        {:error, :webhook_not_found}

      %Webhook{is_active: false} = webhook ->
        Logger.info("Webhook is inactive, skipping #{webhook.id}")
        :ok

      webhook ->
        send_webhook(webhook, payload)
    end
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    Logger.error("Invalid webhook job args: #{inspect(args)}")
    {:error, :invalid_args}
  end

  defp send_webhook(%Webhook{} = webhook, payload) do
    event = payload["event"] || "unknown"
    attempt_number = payload["attempt"] || 1
    triggered_at = DateTime.truncate(DateTime.utc_now(), :second)

    headers = build_headers(webhook, payload)
    request_body = Jason.encode!(payload)

    # Create initial webhook log entry
    {:ok, webhook_log} =
      Webhooks.create_webhook_log(%{
        event: event,
        url: webhook.url,
        http_method: "POST",
        request_headers: headers_to_map(headers),
        request_body: request_body,
        attempt_number: attempt_number,
        triggered_at: triggered_at,
        webhook_id: webhook.id,
        organisation_id: webhook.organisation_id
      })

    # Measure execution time
    start_time = System.monotonic_time(:millisecond)

    case make_http_request(webhook.url, payload, headers, webhook.timeout_seconds) do
      {:ok, %{status_code: status_code, headers: response_headers, body: response_body}}
      when status_code >= 200 and status_code < 300 ->
        execution_time = System.monotonic_time(:millisecond) - start_time

        # Update log with successful response
        Webhooks.update_webhook_log(webhook_log, %{
          response_status: status_code,
          response_headers: headers_to_map(response_headers),
          response_body: truncate_response_body(response_body),
          execution_time_ms: execution_time,
          success: true
        })

        Logger.info("Webhook delivered successfully #{webhook.id}",
          status_code: status_code,
          execution_time_ms: execution_time
        )

        Webhooks.update_webhook_trigger_info(webhook, status_code, true)
        :ok

      {:ok, %{status_code: status_code, headers: response_headers, body: response_body}} ->
        execution_time = System.monotonic_time(:millisecond) - start_time

        # Update log with failed response
        Webhooks.update_webhook_log(webhook_log, %{
          response_status: status_code,
          response_headers: headers_to_map(response_headers),
          response_body: truncate_response_body(response_body),
          execution_time_ms: execution_time,
          success: false,
          error_message: "HTTP #{status_code} response"
        })

        Logger.warning("Webhook delivery failed with non-2xx status #{webhook.id}",
          status_code: status_code,
          execution_time_ms: execution_time
        )

        Webhooks.update_webhook_trigger_info(webhook, status_code, false)
        {:error, :webhook_failed}

      {:error, reason} ->
        execution_time = System.monotonic_time(:millisecond) - start_time
        error_message = format_error_message(reason)

        # Update log with error
        Webhooks.update_webhook_log(webhook_log, %{
          execution_time_ms: execution_time,
          success: false,
          error_message: error_message
        })

        Logger.error("Webhook delivery failed #{webhook.id}",
          reason: inspect(reason),
          execution_time_ms: execution_time
        )

        Webhooks.update_webhook_trigger_info(webhook, 0, false)
        {:error, reason}
    end
  end

  defp build_headers(webhook, payload) do
    base_headers = [
      {"Content-Type", "application/json"},
      {"User-Agent", "WraftDoc-Webhook/1.0"}
    ]

    custom_headers =
      Enum.map(webhook.headers || %{}, fn {k, v} -> {to_string(k), to_string(v)} end)

    signature_header =
      if webhook.secret do
        signature = generate_signature(payload, webhook.secret)
        [{"X-WraftDoc-Signature", signature}]
      else
        []
      end

    base_headers ++ custom_headers ++ signature_header
  end

  defp generate_signature(payload, secret) do
    payload_json = Jason.encode!(payload)
    signature = :crypto.mac(:hmac, :sha256, secret, payload_json)
    "sha256=" <> Base.encode16(signature, case: :lower)
  end

  defp make_http_request(url, payload, headers, timeout_seconds) do
    # Check if this is a Discord webhook and format accordingly
    formatted_payload =
      if discord_webhook?(url) do
        format_discord_payload(payload)
      else
        payload
      end

    body = Jason.encode!(formatted_payload)
    timeout_ms = timeout_seconds * 1000

    HTTPoison.post(url, body, headers, recv_timeout: timeout_ms, timeout: timeout_ms)
  end

  # Check if URL is a Discord webhook
  defp discord_webhook?(url) do
    String.contains?(url, "discord.com/api/webhooks/") or
      String.contains?(url, "discordapp.com/api/webhooks/")
  end

  # Format payload for Discord
  defp format_discord_payload(payload) do
    # Extract data from nested structure if present
    data = payload["data"] || payload
    event = payload["event"] || data["event"] || "unknown"
    content = data["content"] || payload["content"] || "Event triggered"

    color = get_event_color(event)
    emoji = get_event_emoji(event)
    timestamp = DateTime.to_iso8601(DateTime.utc_now())

    # Build the embed
    embed = %{
      title: "#{emoji} #{format_event_title(event)}",
      description: content,
      color: color,
      timestamp: timestamp,
      fields: build_discord_fields(payload, data)
    }

    # Return Discord-formatted payload
    %{
      content: "",
      embeds: [embed]
    }
  end

  # Get color for Discord event
  defp get_event_color(event) do
    case event do
      # Green
      "document.created" -> 5_763_719
      # Blue
      "document.sent" -> 3_447_003
      # Gold
      "document.completed" -> 15_844_367
      # Purple
      "document.signed" -> 8_311_585
      # Orange
      "document.cancelled" -> 15_548_997
      # Red
      "document.rejected" -> 15_158_332
      # Light blue
      "test" -> 9_807_270
      # Light gray
      _ -> 9_936_031
    end
  end

  # Get emoji for Discord event
  defp get_event_emoji(event) do
    case event do
      "document.created" -> "📝"
      "document.sent" -> "📤"
      "document.completed" -> "✅"
      "document.signed" -> "✍️"
      "document.cancelled" -> "❌"
      "document.rejected" -> "🚫"
      "test" -> "🧪"
      _ -> "📋"
    end
  end

  defp format_event_title(event) do
    event
    |> String.replace("_", " ")
    |> String.split(" ")
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp build_discord_fields(payload, data) do
    fields =
      []
      |> add_organization_field(payload, data)
      |> add_document_id_field(data)
      |> add_user_field(data)
      |> add_webhook_id_field(payload)
      |> add_timestamp_field(payload)

    # Limit to 25 fields (Discord limit)
    Enum.take(fields, 25)
  end

  defp add_organization_field(fields, payload, data) do
    if payload["organisation_id"] || data["organization"] do
      org_value = payload["organisation_id"] || data["organization"]
      [%{name: "Organization", value: org_value, inline: true} | fields]
    else
      fields
    end
  end

  defp add_document_id_field(fields, data) do
    if data["document_id"] do
      [%{name: "Document ID", value: data["document_id"], inline: true} | fields]
    else
      fields
    end
  end

  defp add_user_field(fields, data) do
    if data["user"] do
      [%{name: "User", value: data["user"], inline: true} | fields]
    else
      fields
    end
  end

  defp add_webhook_id_field(fields, payload) do
    if payload["webhook_id"] do
      [%{name: "Webhook ID", value: payload["webhook_id"], inline: true} | fields]
    else
      fields
    end
  end

  defp add_timestamp_field(fields, payload) do
    if payload["timestamp"] do
      [%{name: "Time", value: payload["timestamp"], inline: false} | fields]
    else
      fields
    end
  end

  # Helper function to convert headers list to map for logging
  defp headers_to_map(headers) when is_list(headers) do
    Enum.into(headers, %{})
  end

  defp headers_to_map(headers), do: headers || %{}

  # Truncate response body to prevent huge log entries
  defp truncate_response_body(body, max_length \\ 10_000) do
    case body do
      nil ->
        nil

      body when is_binary(body) ->
        if String.length(body) > max_length do
          String.slice(body, 0, max_length) <> "... [truncated]"
        else
          body
        end

      _ ->
        inspect(body)
    end
  end

  # Format error message for logging
  defp format_error_message(reason) do
    case reason do
      %HTTPoison.Error{reason: :timeout} -> "Request timeout"
      %HTTPoison.Error{reason: :nxdomain} -> "Domain not found"
      %HTTPoison.Error{reason: :econnrefused} -> "Connection refused"
      %HTTPoison.Error{reason: error_reason} -> "HTTP error: #{inspect(error_reason)}"
      _ -> inspect(reason)
    end
  end
end
