defmodule WraftDoc.Workflows.Adaptors.HttpAdaptor do
  @moduledoc """
  HTTP adaptor for generic REST API integration.

  Supports template variable interpolation in URLs, headers, and body using `{{variable_name}}` syntax.

  Configuration:
  - url: String (required) - The URL to call (supports template variables)
  - method: String (optional) - HTTP method (default: "GET")
  - headers: Map (optional) - HTTP headers (supports template variables in values)
  - body: String or Map (optional) - Request body (supports template variables if string, or direct map)
  - params: Map (optional) - Query parameters (supports template variables in values)

  Example:
  config: %{
    "url" => "https://api.example.com/users/{{user_id}}",
    "method" => "GET",
    "headers" => %{"Authorization" => "Bearer {{token}}"}
  }
  input_data: %{"user_id" => "123", "token" => "abc"}
  output: {:ok, %{status: 200, body: {...}, headers: {...}}}
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
    with {:ok, url} <- get_url(config, input_data),
         {:ok, method} <- get_method(config),
         {:ok, headers} <- get_headers(config, input_data, credentials),
         {:ok, body} <- get_body(config, input_data),
         {:ok, params} <- get_params(config, input_data) do
      Logger.info("[HttpAdaptor] #{method} #{url}")

      client = build_client(headers)

      case do_request(client, method, url, body, params) do
        {:ok, %Tesla.Env{status: status, body: response_body, headers: response_headers}}
        when status in 200..299 ->
          Logger.info("[HttpAdaptor] Success: #{status}")

          {:ok,
           %{
             status: status,
             body: response_body,
             headers: normalize_headers(response_headers)
           }}

        {:ok, %Tesla.Env{status: status, body: response_body}} ->
          Logger.warning("[HttpAdaptor] Error response: #{status}")

          {:error,
           %{
             status: status,
             body: response_body,
             message: "HTTP request failed with status #{status}"
           }}

        {:error, reason} = error ->
          Logger.error("[HttpAdaptor] Request failed: #{inspect(reason)}")
          error
      end
    end
  end

  @impl true
  def validate_config(config) do
    cond do
      !Map.has_key?(config, "url") ->
        {:error, "url is required"}

      !is_binary(config["url"]) ->
        {:error, "url must be a string"}

      Map.has_key?(config, "method") &&
          config["method"] not in ["GET", "POST", "PUT", "PATCH", "DELETE", "HEAD", "OPTIONS"] ->
        {:error, "method must be one of: GET, POST, PUT, PATCH, DELETE, HEAD, OPTIONS"}

      true ->
        :ok
    end
  end

  defp get_url(config, input_data) do
    url = config["url"]
    {:ok, interpolate_template(url, input_data)}
  end

  defp get_method(config) do
    method = config |> Map.get("method", "GET") |> String.upcase()
    {:ok, String.to_atom(String.downcase(method))}
  end

  defp get_headers(config, input_data, credentials) do
    base_headers = %{
      "Content-Type" => "application/json",
      "User-Agent" => "wraft-workflow-engine"
    }

    config_headers = Map.get(config, "headers", %{})
    # Interpolate header values
    config_headers =
      Enum.reduce(config_headers, %{}, fn {key, value}, acc ->
        Map.put(acc, key, interpolate_template(value, input_data))
      end)

    # Add authorization from credentials if provided
    headers =
      if credentials do
        case Map.get(credentials, "authorization") do
          nil -> base_headers
          auth -> Map.put(base_headers, "Authorization", interpolate_template(auth, input_data))
        end
      else
        base_headers
      end

    # Merge config headers (they override base headers)
    final_headers = Map.merge(headers, config_headers)
    {:ok, final_headers}
  end

  defp get_body(config, input_data) do
    case Map.get(config, "body") do
      nil -> {:ok, nil}
      body when is_binary(body) -> {:ok, interpolate_template(body, input_data)}
      body when is_map(body) -> {:ok, interpolate_map(body, input_data)}
      _ -> {:error, "body must be a string or map"}
    end
  end

  defp get_params(config, input_data) do
    case Map.get(config, "params") do
      nil ->
        {:ok, []}

      params when is_map(params) ->
        # Interpolate param values
        interpolated =
          Enum.reduce(params, [], fn {key, value}, acc ->
            [{key, interpolate_template(value, input_data)} | acc]
          end)

        {:ok, interpolated}

      _ ->
        {:error, "params must be a map"}
    end
  end

  defp build_client(headers) do
    Tesla.client([
      {Tesla.Middleware.Headers, headers}
    ])
  end

  defp do_request(client, method, url, nil, []) when method in [:get, :head, :options] do
    Tesla.request(client, method: method, url: url)
  end

  defp do_request(client, method, url, body, []) when method in [:post, :put, :patch] do
    Tesla.request(client, method: method, url: url, body: body)
  end

  defp do_request(client, method, url, nil, params) when method in [:get, :head, :options] do
    url_with_params = add_query_params(url, params)
    Tesla.request(client, method: method, url: url_with_params)
  end

  defp do_request(client, method, url, body, params)
       when method in [:post, :put, :patch, :delete] do
    url_with_params = add_query_params(url, params)
    Tesla.request(client, method: method, url: url_with_params, body: body)
  end

  defp add_query_params(url, []) do
    url
  end

  defp add_query_params(url, params) do
    query_string = URI.encode_query(params)
    "#{url}?#{query_string}"
  end

  defp interpolate_template(template, data) when is_binary(template) do
    Regex.replace(~r/\{\{(\w+)\}\}/, template, fn _match, var_name ->
      value = Map.get(data, var_name) || Map.get(data, String.to_atom(var_name))
      to_string(value || "{{#{var_name}}}")
    end)
  end

  defp interpolate_map(map, data) when is_map(map) do
    Enum.reduce(map, %{}, fn {key, value}, acc ->
      interpolated_value =
        cond do
          is_binary(value) -> interpolate_template(value, data)
          is_map(value) -> interpolate_map(value, data)
          true -> value
        end

      Map.put(acc, key, interpolated_value)
    end)
  end

  defp normalize_headers(headers) when is_list(headers) do
    Enum.reduce(headers, %{}, fn {key, value}, acc ->
      # Tesla headers are lowercase with underscores, convert to camelCase
      normalized_key =
        key
        |> String.replace("_", "-")
        |> String.split("-")
        |> Enum.map_join("-", &String.capitalize/1)

      Map.put(acc, normalized_key, value)
    end)
  end
end
