defmodule WraftDoc.Workflows.Adaptors.ErpnextAdaptor do
  @moduledoc """
  ERPNext adaptor for sending documents to ERPNext system.

  Supports ERPNext-specific authentication (API token) and document format.
  Can send documents as attachments or inline data.

  Configuration:
  - endpoint: String (required) - ERPNext API endpoint (e.g., "/api/resource/DocType")
  - doctype: String (required) - ERPNext document type (e.g., "Sales Invoice", "Purchase Order")
  - document_field: String (optional) - Field name for document data (default: "document")
  - data: Map (optional) - Additional document fields to send
  - base_url: String (optional) - ERPNext base URL (from credentials if not provided)
  - attachment_field: String (optional) - Field name for file attachment
  - method: String (optional) - HTTP method (default: "POST")

  Credentials format:
  - api_key: String - ERPNext API key
  - api_secret: String - ERPNext API secret
  - base_url: String (optional) - ERPNext base URL

  Example:
  config: %{
    "endpoint" => "/api/resource/Sales Invoice",
    "doctype" => "Sales Invoice",
    "document_field" => "{{previous.document}}",
    "data" => %{"customer" => "{{customer_name}}", "total" => "{{total_amount}}"}
  }
  credentials: %{"api_key" => "key", "api_secret" => "secret", "base_url" => "https://erpnext.example.com"}
  input_data: %{"customer_name" => "Acme Corp", "total_amount" => "1000"}
  """

  @behaviour WraftDoc.Workflows.Adaptors.Adaptor

  use Tesla
  require Logger

  plug Tesla.Middleware.JSON
  plug Tesla.Middleware.FollowRedirects
  plug Tesla.Middleware.Logger

  adapter(Tesla.Adapter.Hackney,
    timeout: 30_000,
    recv_timeout: 30_000
  )

  @impl true
  def execute(config, input_data, credentials) do
    with {:ok, base_url} <- get_base_url(config, credentials),
         {:ok, endpoint} <- get_endpoint(config, input_data),
         {:ok, doctype} <- get_doctype(config),
         {:ok, url} <- build_url(base_url, endpoint),
         {:ok, headers} <- build_headers(credentials),
         {:ok, body} <- build_body(config, input_data, doctype) do
      Logger.info("[ErpnextAdaptor] Sending document to ERPNext: #{url}")

      client = build_client(headers)

      case Tesla.post(client, url, body) do
        {:ok, %Tesla.Env{status: status, body: response_body}} when status in 200..299 ->
          Logger.info("[ErpnextAdaptor] Success: #{status}")

          {:ok,
           %{
             status: status,
             data: response_body,
             doctype: doctype
           }}

        {:ok, %Tesla.Env{status: status, body: response_body}} ->
          Logger.warning("[ErpnextAdaptor] Error response: #{status}")

          {:error,
           %{
             status: status,
             body: response_body,
             message: "ERPNext request failed with status #{status}"
           }}

        {:error, reason} = error ->
          Logger.error("[ErpnextAdaptor] Request failed: #{inspect(reason)}")
          error
      end
    end
  end

  @impl true
  def validate_config(config) do
    cond do
      !Map.has_key?(config, "endpoint") -> {:error, "endpoint is required"}
      !is_binary(config["endpoint"]) -> {:error, "endpoint must be a string"}
      !Map.has_key?(config, "doctype") -> {:error, "doctype is required"}
      !is_binary(config["doctype"]) -> {:error, "doctype must be a string"}
      true -> :ok
    end
  end

  defp get_base_url(config, credentials) do
    base_url =
      Map.get(config, "base_url") ||
        Map.get(credentials || %{}, "base_url") ||
        Map.get(credentials || %{}, "baseUrl")

    if base_url do
      {:ok, String.trim_trailing(base_url, "/")}
    else
      {:error, "base_url is required (provide in config or credentials)"}
    end
  end

  defp get_endpoint(config, input_data) do
    endpoint = config["endpoint"]
    {:ok, interpolate_template(endpoint, input_data)}
  end

  defp get_doctype(config) do
    doctype = config["doctype"]
    {:ok, doctype}
  end

  defp build_url(base_url, endpoint) do
    # Ensure endpoint starts with /
    endpoint = if String.starts_with?(endpoint, "/"), do: endpoint, else: "/#{endpoint}"
    {:ok, "#{base_url}#{endpoint}"}
  end

  defp build_headers(credentials) do
    headers = %{
      "Content-Type" => "application/json",
      "Accept" => "application/json"
    }

    auth_headers =
      case credentials do
        %{"api_key" => key, "api_secret" => secret} ->
          # ERPNext uses token format: key:secret
          token = Base.encode64("#{key}:#{secret}")
          Map.put(headers, "Authorization", "token #{token}")

        %{"token" => token} ->
          Map.put(headers, "Authorization", "token #{token}")

        _ ->
          headers
      end

    {:ok, auth_headers}
  end

  defp build_body(config, input_data, doctype) do
    # Start with base data
    data = Map.get(config, "data", %{})
    # Interpolate template variables in data
    data = interpolate_map(data, input_data)

    # Add doctype
    data = Map.put(data, "doctype", doctype)

    # Handle document field (can reference previous workflow steps)
    document_field = Map.get(config, "document_field", "document")

    case resolve_document(document_field, input_data) do
      {:ok, document_data} when document_data != nil ->
        # Add document data to the body
        attachment_field = Map.get(config, "attachment_field", "document")
        data = Map.put(data, attachment_field, document_data)
        {:ok, %{data: data}}

      {:ok, nil} ->
        # No document data, just send the data
        {:ok, %{data: data}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp resolve_document(document_field, input_data) when is_binary(document_field) do
    if previous_reference?(document_field) do
      resolve_previous_document(document_field, input_data)
    else
      value =
        Map.get(input_data, document_field) ||
          Map.get(input_data, String.to_atom(document_field))

      normalize_document_data(value)
    end
  end

  defp resolve_document(_, _), do: {:ok, nil}

  defp build_client(headers) do
    Tesla.client([
      {Tesla.Middleware.Headers, headers}
    ])
  end

  defp interpolate_template(template, data) when is_binary(template) do
    Regex.replace(~r/\{\{(\w+)\}\}/, template, fn _match, var_name ->
      value =
        Map.get(data, var_name) ||
          Map.get(data, String.to_atom(var_name)) ||
          (Map.get(data, "previous") && Map.get(Map.get(data, "previous"), var_name))

      to_string(value || "{{#{var_name}}}")
    end)
  end

  defp interpolate_map(map, data) when is_map(map) do
    Enum.reduce(map, %{}, fn {key, value}, acc ->
      Map.put(acc, key, interpolate_value(value, data))
    end)
  end

  defp interpolate_value(value, data) when is_binary(value), do: interpolate_template(value, data)
  defp interpolate_value(value, data) when is_map(value), do: interpolate_map(value, data)

  defp interpolate_value(value, data) when is_list(value) do
    Enum.map(value, &interpolate_collection_item(&1, data))
  end

  defp interpolate_value(value, _data), do: value

  defp interpolate_collection_item(item, data) when is_map(item), do: interpolate_map(item, data)
  defp interpolate_collection_item(item, _data), do: item

  defp previous_reference?(value), do: String.contains?(value, "{{previous.")

  defp resolve_previous_document(document_field, input_data) do
    with [_, step_name] <- Regex.run(~r/\{\{previous\.(\w+)\}\}/, document_field),
         {:ok, step_output} <- fetch_step_output(input_data, step_name) do
      normalize_document_data(step_output)
    else
      nil -> {:error, "Invalid document field format"}
      {:error, _} = error -> error
    end
  end

  defp fetch_step_output(input_data, step_name) do
    output = Map.get(input_data, step_name) || Map.get(input_data, String.to_atom(step_name))
    {:ok, output}
  end

  defp normalize_document_data(nil), do: {:ok, nil}

  defp normalize_document_data(%{"document" => data}) when is_binary(data),
    do: encode_binary(data)

  defp normalize_document_data(%{"file" => data}) when is_binary(data), do: encode_binary(data)
  defp normalize_document_data(binary) when is_binary(binary), do: encode_binary(binary)
  defp normalize_document_data(_), do: {:ok, nil}

  defp encode_binary(data) do
    case Base.decode64(data) do
      {:ok, decoded} -> {:ok, Base.encode64(decoded)}
      :error -> {:ok, Base.encode64(data)}
    end
  end
end
