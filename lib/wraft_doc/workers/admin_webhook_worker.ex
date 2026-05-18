defmodule WraftDoc.Workers.AdminWebhookWorker do
  @moduledoc """
  Oban worker for delivering admin webhook events. Mirrors
  `WraftDoc.Workers.WebhookWorker` but for system-wide admin webhooks.
  """
  use Oban.Worker, queue: :webhooks, max_attempts: 5
  require Logger

  alias WraftDoc.AdminWebhooks
  alias WraftDoc.AdminWebhooks.AdminWebhook
  alias WraftDoc.Repo

  @signature_header "X-WraftDoc-Admin-Signature"
  @user_agent "WraftDoc-Admin-Webhook/1.0"
  @max_response_body_length 10_000

  @impl Oban.Worker
  def perform(%Oban.Job{
        attempt: attempt,
        args: %{
          "webhook_id" => webhook_id,
          "event" => event,
          "payload" => payload
        }
      }) do
    Logger.info("Processing admin webhook #{webhook_id} event #{event} attempt #{attempt}")

    case Repo.get(AdminWebhook, webhook_id) do
      nil ->
        Logger.error("Admin webhook not found #{webhook_id}")
        {:error, :webhook_not_found}

      %AdminWebhook{is_active: false} = webhook ->
        Logger.info("Admin webhook is inactive, skipping #{webhook.id}")
        :ok

      webhook ->
        send_webhook(webhook, payload, attempt)
    end
  end

  def perform(%Oban.Job{args: args}) do
    Logger.error("Invalid admin webhook job args: #{inspect(args)}")
    {:error, :invalid_args}
  end

  defp send_webhook(%AdminWebhook{} = webhook, payload, attempt_number) do
    event = payload["event"] || "unknown"
    triggered_at = DateTime.truncate(DateTime.utc_now(), :second)

    # Decide the wire body + headers BEFORE writing the log row, so the audit
    # log accurately reflects what was actually sent (Discord deliveries use a
    # different body shape and a minimal header set).
    {request_body, headers} = build_request(webhook, payload)

    {:ok, log} =
      AdminWebhooks.create_admin_webhook_log(%{
        event: event,
        url: webhook.url,
        http_method: "POST",
        request_headers: headers_to_map(headers),
        request_body: request_body,
        attempt_number: attempt_number,
        triggered_at: triggered_at,
        webhook_id: webhook.id
      })

    start_time = System.monotonic_time(:millisecond)

    case make_http_request(webhook.url, request_body, headers, webhook.timeout_seconds) do
      {:ok, %{status_code: status_code, headers: response_headers, body: response_body}}
      when status_code >= 200 and status_code < 300 ->
        execution_time = System.monotonic_time(:millisecond) - start_time

        AdminWebhooks.update_admin_webhook_log(log, %{
          response_status: status_code,
          response_headers: headers_to_map(response_headers),
          response_body: truncate_response_body(response_body),
          execution_time_ms: execution_time,
          success: true
        })

        Logger.info("Admin webhook delivered successfully #{webhook.id}",
          status_code: status_code,
          execution_time_ms: execution_time
        )

        AdminWebhooks.update_admin_webhook_trigger_info(webhook, status_code, true)
        :ok

      {:ok, %{status_code: status_code, headers: response_headers, body: response_body}} ->
        execution_time = System.monotonic_time(:millisecond) - start_time

        AdminWebhooks.update_admin_webhook_log(log, %{
          response_status: status_code,
          response_headers: headers_to_map(response_headers),
          response_body: truncate_response_body(response_body),
          execution_time_ms: execution_time,
          success: false,
          error_message: "HTTP #{status_code} response"
        })

        Logger.warning("Admin webhook delivery failed with non-2xx #{webhook.id}",
          status_code: status_code,
          execution_time_ms: execution_time
        )

        AdminWebhooks.update_admin_webhook_trigger_info(webhook, status_code, false)
        {:error, :webhook_failed}

      {:error, reason} ->
        execution_time = System.monotonic_time(:millisecond) - start_time
        error_message = format_error_message(reason)

        AdminWebhooks.update_admin_webhook_log(log, %{
          execution_time_ms: execution_time,
          success: false,
          error_message: error_message
        })

        Logger.error("Admin webhook delivery failed #{webhook.id}",
          reason: inspect(reason),
          execution_time_ms: execution_time
        )

        AdminWebhooks.update_admin_webhook_trigger_info(webhook, 0, false)
        {:error, reason}
    end
  end

  @doc false
  # Public for direct testing. Returns `{body, headers}` to send on the wire.
  # Discord URLs get the Discord-shaped body and a minimal header set (HMAC
  # signing is skipped because Discord can't verify it).
  def build_request(%AdminWebhook{} = webhook, payload) do
    if discord_webhook?(webhook.url) do
      body = Jason.encode!(format_discord_payload(payload))
      {body, [{"Content-Type", "application/json"}]}
    else
      body = Jason.encode!(payload)
      {body, build_signed_headers(webhook, body)}
    end
  end

  defp build_signed_headers(webhook, request_body) do
    base_headers = [
      {"Content-Type", "application/json"},
      {"User-Agent", @user_agent}
    ]

    custom_headers =
      Enum.map(webhook.headers || %{}, fn {k, v} -> {to_string(k), to_string(v)} end)

    signature_header =
      if webhook.secret do
        [{@signature_header, generate_signature(request_body, webhook.secret)}]
      else
        []
      end

    base_headers ++ custom_headers ++ signature_header
  end

  @doc false
  # Public for direct testing — not part of the worker's external API.
  def generate_signature(request_body, secret) when is_binary(request_body) do
    signature = :crypto.mac(:hmac, :sha256, secret, request_body)
    "sha256=" <> Base.encode16(signature, case: :lower)
  end

  defp make_http_request(url, body, headers, timeout_seconds) do
    timeout_ms = timeout_seconds * 1000
    HTTPoison.post(url, body, headers, recv_timeout: timeout_ms, timeout: timeout_ms)
  end

  defp discord_webhook?(url) do
    String.contains?(url, "discord.com/api/webhooks/") or
      String.contains?(url, "discordapp.com/api/webhooks/")
  end

  @doc false
  # Public for direct testing. Converts the admin webhook envelope into
  # Discord's `{content, embeds: [...]}` shape. `allowed_mentions: %{parse: []}`
  # disables ALL mention processing — without it, a user named "@everyone"
  # would ping the entire Discord server when their event is delivered.
  def format_discord_payload(payload) do
    event = payload["event"] || "unknown"
    data = payload["data"] || %{}
    actor = payload["actor"] || %{}

    embed = %{
      title: "#{discord_emoji(event)} #{discord_title(event)}",
      description: discord_description(event, data, actor),
      color: discord_color(event),
      timestamp: payload["timestamp"] || DateTime.to_iso8601(DateTime.utc_now()),
      fields: discord_fields(event, data)
    }

    %{content: "", embeds: [embed], allowed_mentions: %{parse: []}}
  end

  # Discord embed color values (decimal RGB).
  @discord_color_green 5_763_719
  @discord_color_blue 3_447_003
  @discord_color_gold 15_844_367
  @discord_color_red 15_158_332
  @discord_color_light_blue 9_807_270
  @discord_color_grey 9_936_031

  defp discord_color(event) do
    cond do
      String.ends_with?(event, ".approved") -> @discord_color_gold
      String.ends_with?(event, ".created") -> @discord_color_green
      String.ends_with?(event, ".updated") -> @discord_color_blue
      String.ends_with?(event, ".deleted") -> @discord_color_red
      event == "admin.test" -> @discord_color_light_blue
      true -> @discord_color_grey
    end
  end

  defp discord_emoji(event) do
    cond do
      String.ends_with?(event, ".approved") -> "🎉"
      String.ends_with?(event, ".confirmation_email_sent") -> "✉️"
      String.contains?(event, ".user.") -> "👤"
      String.contains?(event, ".organisation.") -> "🏢"
      String.contains?(event, ".waiting_list.") -> "📋"
      event == "admin.test" -> "🧪"
      true -> "🛡️"
    end
  end

  @discord_titles %{
    "admin.user.created" => "New user registered",
    "admin.user.updated" => "User updated",
    "admin.user.deleted" => "User deleted",
    "admin.organisation.created" => "New organisation created",
    "admin.organisation.updated" => "Organisation updated",
    "admin.organisation.deleted" => "Organisation deleted",
    "admin.waiting_list.created" => "Joined the waiting list",
    "admin.waiting_list.updated" => "Waiting list entry updated",
    "admin.waiting_list.approved" => "Waiting list entry approved",
    "admin.waiting_list.deleted" => "Waiting list entry deleted",
    "admin.waiting_list.confirmation_email_sent" => "Waiting list confirmation email sent",
    "admin.test" => "Test event"
  }

  defp discord_title(event),
    do: Map.get_lazy(@discord_titles, event, fn -> humanize_event(event) end)

  defp humanize_event(event) do
    event
    |> String.replace("_", " ")
    |> String.split(".")
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp discord_description(event, data, actor) do
    actor_text = discord_actor_text(actor)

    cond do
      user = data["user"] -> describe_user(user, event, actor_text)
      org = data["organisation"] -> describe_organisation(org, event, data, actor_text)
      wl = data["waiting_list"] -> describe_waiting_list(wl, event, actor_text)
      msg = data["message"] -> msg
      true -> "Admin event `#{event}` was triggered#{actor_text}."
    end
  end

  defp describe_user(user, event, actor_text) do
    name = user["name"] || user["email"] || "User"
    "**#{name}** (#{user["email"]}) was #{past_tense(event)}#{actor_text}."
  end

  defp describe_organisation(org, event, data, actor_text) do
    verb = if data["soft_deleted"], do: "soft-deleted", else: past_tense(event)
    "Organisation **#{org["name"]}** was #{verb}#{actor_text}."
  end

  defp describe_waiting_list(wl, event, actor_text) do
    name = waiting_list_display_name(wl)
    email = wl["email"]

    case event do
      "admin.waiting_list.created" ->
        "**#{name}** (#{email}) joined the waiting list."

      "admin.waiting_list.approved" ->
        "**#{name}** (#{email}) was approved#{actor_text}. They'll receive a set-password email shortly."

      "admin.waiting_list.deleted" ->
        "**#{name}** (#{email}) was removed from the waiting list#{actor_text}."

      "admin.waiting_list.confirmation_email_sent" ->
        "Confirmation email queued for **#{name}** (#{email})."

      _ ->
        "**#{name}** (#{email}) — status: `#{wl["status"]}`#{actor_text}."
    end
  end

  defp discord_actor_text(%{"email" => email}) when is_binary(email) and email != "",
    do: " by **#{email}**"

  defp discord_actor_text(_), do: ""

  defp past_tense(event) do
    cond do
      String.ends_with?(event, ".created") -> "created"
      String.ends_with?(event, ".updated") -> "updated"
      String.ends_with?(event, ".deleted") -> "deleted"
      String.ends_with?(event, ".approved") -> "approved"
      true -> "changed"
    end
  end

  defp waiting_list_display_name(wl) do
    full = String.trim("#{wl["first_name"] || ""} #{wl["last_name"] || ""}")
    if full == "", do: wl["email"] || "Anonymous", else: full
  end

  defp discord_fields(event, data) do
    []
    |> maybe_add_field("ID", resource_id(data))
    |> maybe_add_field("Event", event)
    |> Enum.reverse()
    |> Enum.take(25)
  end

  defp resource_id(data) do
    cond do
      user = data["user"] -> user["id"]
      org = data["organisation"] -> org["id"]
      wl = data["waiting_list"] -> wl["id"]
      true -> nil
    end
  end

  defp maybe_add_field(fields, _name, nil), do: fields
  defp maybe_add_field(fields, _name, false), do: fields
  defp maybe_add_field(fields, _name, ""), do: fields

  defp maybe_add_field(fields, name, value),
    do: [%{name: name, value: to_string(value), inline: true} | fields]

  defp headers_to_map(headers) when is_list(headers), do: Enum.into(headers, %{})
  defp headers_to_map(headers) when is_map(headers), do: headers
  defp headers_to_map(_), do: %{}

  defp truncate_response_body(nil), do: nil

  defp truncate_response_body(body) when is_binary(body) do
    if byte_size(body) > @max_response_body_length do
      binary_part(body, 0, @max_response_body_length) <> "... [truncated]"
    else
      body
    end
  end

  defp truncate_response_body(body), do: inspect(body)

  defp format_error_message(%HTTPoison.Error{reason: :timeout}), do: "Request timeout"
  defp format_error_message(%HTTPoison.Error{reason: :nxdomain}), do: "Domain not found"
  defp format_error_message(%HTTPoison.Error{reason: :econnrefused}), do: "Connection refused"

  defp format_error_message(%HTTPoison.Error{reason: reason}),
    do: "HTTP error: #{inspect(reason)}"

  defp format_error_message(reason), do: inspect(reason)
end
