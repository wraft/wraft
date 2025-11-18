defmodule WraftDoc.Workflows.Adaptors.WebhookProcessorAdaptor do
  @moduledoc """
  Webhook processor adaptor for processing incoming webhooks and sending responses.

  This adaptor handles webhook payloads, processes them, and can send responses
  back to the webhook sender. Useful for ERPNext invoice webhooks and similar scenarios.

  Configuration:
  - webhook_secret: String (optional) - Secret for verifying webhook signature
  - process_payload: Map (optional) - How to process the webhook payload
    - extract_fields: Map - Field extraction mapping
    - transform: Map - Data transformation rules
  - response_endpoint: String (optional) - Endpoint to send response to
  - response_method: String (optional) - HTTP method for response (default: "POST")
  - response_data: Map (optional) - Data to include in response (supports template variables)

  Example:
  config: %{
    "webhook_secret" => "secret123",
    "process_payload" => %{
      "extract_fields" => %{
        "invoice_number" => "data.invoice_no",
        "amount" => "data.grand_total"
      }
    },
    "response_endpoint" => "https://erpnext.example.com/api/resource/Sales Invoice",
    "response_data" => %{
      "invoice_id" => "{{processed.invoice_number}}",
      "document_url" => "{{document.url}}"
    }
  }
  input_data: %{"webhook_payload" => %{"data" => %{"invoice_no" => "INV-001", "grand_total" => 1000}}}
  """

  @behaviour WraftDoc.Workflows.Adaptors.Adaptor

  require Logger

  alias WraftDoc.Workflows.Adaptors.HttpAdaptor

  @impl true
  def execute(config, input_data, credentials) do
    with {:ok, webhook_payload} <- get_webhook_payload(input_data),
         {:ok, _verified} <- verify_webhook(config, webhook_payload, input_data),
         {:ok, processed_data} <- process_payload(config, webhook_payload, input_data) do
      Logger.info("[WebhookProcessorAdaptor] Webhook processed successfully")

      # Send response if endpoint is configured
      response_result =
        case Map.get(config, "response_endpoint") do
          nil -> {:ok, nil}
          _endpoint -> send_response(config, processed_data, credentials)
        end

      case response_result do
        {:ok, response} ->
          {:ok,
           Map.merge(processed_data, %{
             webhook_processed: true,
             response_sent: response != nil,
             response: response
           })}

        {:error, reason} ->
          Logger.warning("[WebhookProcessorAdaptor] Failed to send response: #{inspect(reason)}")
          # Still return success for processing, but note response failure
          {:ok,
           Map.merge(processed_data, %{
             webhook_processed: true,
             response_sent: false,
             response_error: inspect(reason)
           })}
      end
    end
  end

  @impl true
  def validate_config(_config), do: :ok

  defp get_webhook_payload(input_data) do
    # Webhook payload can come from various keys
    payload =
      Map.get(input_data, "webhook_payload") ||
        Map.get(input_data, "payload") ||
        Map.get(input_data, "data") ||
        input_data

    if is_map(payload) do
      {:ok, payload}
    else
      {:error, "webhook payload must be a map"}
    end
  end

  defp verify_webhook(config, webhook_payload, input_data) do
    case Map.get(config, "webhook_secret") do
      nil ->
        # No secret configured, skip verification
        {:ok, true}

      secret ->
        # Verify HMAC-SHA256 signature if provided in headers
        case Map.get(input_data, "signature") || Map.get(input_data, "headers") do
          nil ->
            Logger.warning(
              "[WebhookProcessorAdaptor] No signature provided, skipping verification"
            )

            {:ok, true}

          provided_signature ->
            verify_hmac_signature(webhook_payload, secret, provided_signature)
        end
    end
  end

  defp verify_hmac_signature(payload, secret, provided_signature) do
    # Create signature from payload
    payload_string = Jason.encode!(payload)

    expected_signature =
      :hmac
      |> :crypto.mac(:sha256, secret, payload_string)
      |> Base.encode16(case: :lower)

    if provided_signature == expected_signature do
      {:ok, true}
    else
      Logger.error("[WebhookProcessorAdaptor] Signature verification failed")
      {:error, "Invalid webhook signature"}
    end
  end

  defp process_payload(config, webhook_payload, input_data) do
    process_config = Map.get(config, "process_payload", %{})

    # Extract fields if mapping is provided
    extracted =
      case Map.get(process_config, "extract_fields") do
        nil ->
          webhook_payload

        field_mapping when is_map(field_mapping) ->
          extract_fields(webhook_payload, field_mapping)

        _ ->
          webhook_payload
      end

    # Apply transformations if specified
    transformed =
      case Map.get(process_config, "transform") do
        nil ->
          extracted

        transform_rules when is_map(transform_rules) ->
          apply_transforms(extracted, transform_rules)

        _ ->
          extracted
      end

    # Merge with input_data for template interpolation
    {:ok, Map.merge(input_data, %{processed: transformed, original_payload: webhook_payload})}
  end

  defp extract_fields(data, field_mapping) do
    Enum.reduce(field_mapping, %{}, fn {key, path}, acc ->
      value = get_nested_value(data, path)

      if value != nil do
        Map.put(acc, key, value)
      else
        acc
      end
    end)
  end

  defp apply_transforms(data, transform_rules) do
    Enum.reduce(transform_rules, data, fn {field, transform}, acc ->
      case Map.get(acc, field) do
        nil -> acc
        value -> Map.put(acc, field, apply_transform(value, transform))
      end
    end)
  end

  defp apply_transform(value, "to_string"), do: to_string(value)

  defp apply_transform(value, "to_number") do
    case Float.parse(to_string(value)) do
      {num, _} -> num
      :error -> value
    end
  end

  defp apply_transform(value, "uppercase"), do: String.upcase(to_string(value))

  defp apply_transform(value, "lowercase"), do: String.downcase(to_string(value))

  defp apply_transform(value, _transform), do: value

  defp send_response(config, processed_data, credentials) do
    endpoint = config["response_endpoint"]
    method = String.upcase(Map.get(config, "response_method", "POST"))
    response_data = Map.get(config, "response_data", %{})

    # Interpolate template variables in response_data
    interpolated_data = interpolate_map(response_data, processed_data)

    # Build HTTP config for sending response
    http_config = %{
      "url" => endpoint,
      "method" => method,
      "body" => interpolated_data,
      "headers" => %{
        "Content-Type" => "application/json"
      }
    }

    # Use HttpAdaptor to send the response
    case HttpAdaptor.execute(http_config, processed_data, credentials) do
      {:ok, result} ->
        Logger.info("[WebhookProcessorAdaptor] Response sent successfully to #{endpoint}")
        {:ok, result}

      error ->
        error
    end
  end

  defp get_nested_value(map, path) when is_map(map) and is_binary(path) do
    path_parts = String.split(path, ".")
    get_nested_value(map, path_parts)
  end

  defp get_nested_value(map, [key]) when is_map(map) do
    Map.get(map, key) || Map.get(map, String.to_atom(key))
  end

  defp get_nested_value(map, [key | rest]) when is_map(map) do
    value = Map.get(map, key) || Map.get(map, String.to_atom(key))

    if is_map(value) do
      get_nested_value(value, rest)
    else
      nil
    end
  end

  defp get_nested_value(_, _), do: nil

  defp interpolate_template(template, data) when is_binary(template) do
    Regex.replace(~r/\{\{(\w+\.?\w*)\}\}/, template, fn _match, var_name ->
      # Support dot notation (e.g., "processed.invoice_number")
      value =
        if String.contains?(var_name, ".") do
          get_nested_value(data, var_name)
        else
          Map.get(data, var_name) ||
            Map.get(data, String.to_atom(var_name)) ||
            (Map.get(data, "processed") && get_nested_value(Map.get(data, "processed"), var_name))
        end

      to_string(value || "{{#{var_name}}}")
    end)
  end

  defp interpolate_map(map, data) when is_map(map) do
    Enum.reduce(map, %{}, fn {key, value}, acc ->
      interpolated_value = interpolate_value(value, data)
      Map.put(acc, key, interpolated_value)
    end)
  end

  defp interpolate_value(value, data) when is_binary(value),
    do: interpolate_template(value, data)

  defp interpolate_value(value, data) when is_map(value),
    do: interpolate_map(value, data)

  defp interpolate_value(value, data) when is_list(value),
    do: Enum.map(value, &interpolate_list_item(&1, data))

  defp interpolate_value(value, _data), do: value

  defp interpolate_list_item(item, data) when is_map(item),
    do: interpolate_map(item, data)

  defp interpolate_list_item(item, _data), do: item
end
