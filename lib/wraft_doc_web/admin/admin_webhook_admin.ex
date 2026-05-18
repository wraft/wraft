defmodule WraftDocWeb.AdminWebhookAdmin do
  @moduledoc """
  Kaffy admin panel for managing system-wide admin webhooks.
  """
  import Ecto.Query

  alias WraftDoc.AdminWebhooks
  alias WraftDoc.AdminWebhooks.AdminEventTrigger
  alias WraftDoc.AdminWebhooks.AdminWebhook

  def index(_) do
    [
      name: %{name: "Name", value: fn x -> x.name end},
      url: %{name: "URL", value: fn x -> x.url end},
      events: %{
        name: "Events",
        value: fn x -> x.events |> List.wrap() |> Enum.join(", ") end
      },
      is_active: %{
        name: "Active",
        value: fn x -> if x.is_active, do: "Active", else: "Inactive" end,
        filters: [{"Active", "true"}, {"Inactive", "false"}]
      },
      last_triggered_at: %{name: "Last Triggered", value: fn x -> x.last_triggered_at end},
      last_response_status: %{name: "Last Status", value: fn x -> x.last_response_status end},
      failure_count: %{name: "Failures", value: fn x -> x.failure_count end},
      creator: %{
        name: "Creator",
        value: fn x ->
          if x.creator, do: Map.get(x.creator, :email), else: "N/A"
        end
      },
      inserted_at: %{name: "Created At", value: fn x -> x.inserted_at end}
    ]
  end

  def form_fields(_) do
    events_help =
      ~s|JSON array. Allowed: | <> Enum.join(AdminWebhooks.available_events(), ", ")

    [
      name: %{label: "Name"},
      url: %{label: "URL", help_text: "HTTPS endpoint that will receive signed POSTs"},
      secret: %{
        label: "Signing Secret",
        type: :password,
        help_text: "HMAC-SHA256 key for the X-WraftDoc-Admin-Signature header"
      },
      # No `type:` override — Kaffy's built-in {:array, _} renderer encodes the
      # value to JSON for the textarea and we JSON-decode it on submit.
      events: %{label: "Events", help_text: events_help},
      is_active: %{label: "Active", type: :boolean},
      # No `type:` override — Kaffy's built-in :map renderer JSON-encodes the
      # value into a textarea and we JSON-decode it on submit.
      headers: %{
        label: "Custom Headers",
        help_text: ~s|JSON object. Example: {"X-API-Key": "abc"}|
      },
      retry_count: %{label: "Retry Count", type: :integer},
      timeout_seconds: %{label: "Timeout (seconds)", type: :integer},
      creator_id: %{create: :hidden, update: :readonly}
    ]
  end

  def ordering(_schema), do: [desc: :inserted_at]

  def custom_index_query(conn, _schema, query) do
    query = from(q in query, preload: [:creator])

    case Map.get(conn.query_params, "is_active") do
      "true" -> from(q in query, where: q.is_active == true)
      "false" -> from(q in query, where: q.is_active == false)
      _ -> query
    end
  end

  def custom_show_query(_, _, query), do: from(q in query, preload: [:creator])

  def resource_actions(_conn) do
    [
      send_test_event: %{
        name: "Send Test Event",
        action: fn conn, webhook -> send_test_event(conn, webhook) end
      },
      activate: %{
        name: "Activate",
        action: fn _conn, webhook ->
          AdminWebhooks.update_admin_webhook(webhook, %{"is_active" => true})
        end
      },
      deactivate: %{
        name: "Deactivate",
        action: fn _conn, webhook ->
          AdminWebhooks.update_admin_webhook(webhook, %{"is_active" => false})
        end
      }
    ]
  end

  def insert(
        %{assigns: %{admin_session: %{id: internal_user_id}}, params: %{"admin_webhook" => params}},
        _changeset
      ) do
    AdminWebhooks.create_admin_webhook(internal_user_id, normalize_params(params))
  end

  def update(%{params: %{"admin_webhook" => params}}, %{data: webhook} = _changeset) do
    AdminWebhooks.update_admin_webhook(webhook, normalize_params(params))
  end

  defp send_test_event(conn, %AdminWebhook{} = webhook) do
    if "admin.test" in (webhook.events || []) do
      AdminEventTrigger.trigger_test(actor(conn))
      {:ok, webhook}
    else
      {:error, webhook, "Webhook is not subscribed to admin.test event"}
    end
  end

  defp actor(%{assigns: %{admin_session: %{id: id, email: email}}}),
    do: %{id: id, email: email}

  defp actor(_), do: nil

  # Kaffy submits :map and {:array, _} fields as JSON-encoded strings (the
  # value of the textarea). Decode them here when possible; on invalid input,
  # leave the raw string in place so Ecto's cast emits a clear `is invalid`
  # error while preserving the user's other form input.
  defp normalize_params(params) do
    params
    |> normalize_json_field("events", &is_list/1)
    |> normalize_json_field("headers", &is_map/1)
  end

  defp normalize_json_field(%{} = params, key, valid_fun) do
    case Map.get(params, key) do
      value when is_binary(value) ->
        case String.trim(value) do
          "" ->
            params

          trimmed ->
            case Jason.decode(trimmed) do
              {:ok, decoded} ->
                if valid_fun.(decoded), do: Map.put(params, key, decoded), else: params

              {:error, _} ->
                params
            end
        end

      _ ->
        params
    end
  end
end
