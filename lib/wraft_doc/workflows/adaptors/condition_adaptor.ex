defmodule WraftDoc.Workflows.Adaptors.ConditionAdaptor do
  @moduledoc """
  Condition evaluation adaptor.

  Evaluates simple conditions against input data.

  Configuration:
  - field: String - field name to check (e.g., "age")
  - operator: String - comparison operator (">", "<", ">=", "<=", "==", "!=")
  - value: Any - value to compare against

  Example:
  config: %{"field" => "age", "operator" => ">", "value" => 25}
  input_data: %{"age" => 30, "name" => "John"}
  output: {:ok, %{result: true, field: "age", operator: ">", value: 25, actual_value: 30}}
  """

  @behaviour WraftDoc.Workflows.Adaptors.Adaptor

  require Logger

  @impl true
  def execute(config, input_data, _credentials) do
    with {:ok, field} <- get_field(config),
         {:ok, operator} <- get_operator(config),
         {:ok, expected_value} <- get_value(config),
         {:ok, actual_value} <- get_actual_value(input_data, field),
         {:ok, result} <- evaluate(actual_value, operator, expected_value) do
      {:ok,
       %{
         result: result,
         field: field,
         operator: operator,
         value: expected_value,
         actual_value: actual_value
       }}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def validate_config(config) do
    cond do
      !Map.has_key?(config, "field") ->
        {:error, "field is required"}

      !Map.has_key?(config, "operator") ->
        {:error, "operator is required"}

      !Map.has_key?(config, "value") ->
        {:error, "value is required"}

      config["operator"] not in [">", "<", ">=", "<=", "==", "!="] ->
        {:error, "operator must be one of: >, <, >=, <=, ==, !="}

      true ->
        :ok
    end
  end

  defp get_field(config) do
    case Map.get(config, "field") do
      nil -> {:error, "field is required in config"}
      field -> {:ok, field}
    end
  end

  defp get_operator(config) do
    case Map.get(config, "operator") do
      nil -> {:error, "operator is required in config"}
      operator when operator in [">", "<", ">=", "<=", "==", "!="] -> {:ok, operator}
      invalid -> {:error, "invalid operator: #{invalid}"}
    end
  end

  defp get_value(config) do
    case Map.get(config, "value") do
      nil -> {:error, "value is required in config"}
      value -> {:ok, value}
    end
  end

  defp get_actual_value(input_data, field) do
    get_actual_value_direct(input_data, field) ||
      get_actual_value_nested(input_data, field) ||
      get_actual_value_from_fields_by_name(input_data, field) ||
      {:error, "field '#{field}' not found in input data"}
  end

  defp get_actual_value_direct(input_data, field) do
    direct = Map.get(input_data, field)

    value =
      if is_nil(direct) && is_binary(field) do
        Map.get(input_data, String.to_atom(field))
      else
        direct
      end

    case value do
      nil -> nil
      value -> {:ok, value}
    end
  end

  defp get_actual_value_nested(input_data, field) do
    case get_nested_value(input_data, field) do
      nil -> nil
      value -> {:ok, value}
    end
  end

  defp get_actual_value_from_fields_by_name(input_data, field) do
    fields_by_name = Map.get(input_data, "fields_by_name") || %{}
    val_named = get_from_fields_by_name(fields_by_name, field)

    cond do
      not is_nil(val_named) ->
        {:ok, val_named}

      (val_ci = find_case_insensitive(fields_by_name, field)) != nil ->
        {:ok, val_ci}

      true ->
        nil
    end
  end

  defp get_from_fields_by_name(fields_by_name, field) do
    direct = Map.get(fields_by_name, field)

    if is_nil(direct) && is_binary(field) do
      Map.get(fields_by_name, String.to_atom(field))
    else
      direct
    end
  end

  defp get_nested_value(map, path) when is_map(map) and is_binary(path) do
    parts = String.split(path, ".")
    get_nested_value(map, parts)
  end

  defp get_nested_value(map, [k]) when is_map(map) do
    Map.get(map, k) || Map.get(map, String.to_atom(k))
  end

  defp get_nested_value(map, [k | rest]) when is_map(map) do
    next = Map.get(map, k) || Map.get(map, String.to_atom(k))
    if is_map(next), do: get_nested_value(next, rest), else: nil
  end

  defp get_nested_value(_, _), do: nil

  defp find_case_insensitive(map, key) when is_map(map) and is_binary(key) do
    down = String.downcase(key)

    Enum.find_value(map, fn {k, v} ->
      if String.downcase(to_string(k)) == down, do: v, else: nil
    end)
  end

  defp evaluate(actual, ">", expected), do: {:ok, actual > expected}
  defp evaluate(actual, "<", expected), do: {:ok, actual < expected}
  defp evaluate(actual, ">=", expected), do: {:ok, actual >= expected}
  defp evaluate(actual, "<=", expected), do: {:ok, actual <= expected}
  defp evaluate(actual, "==", expected), do: {:ok, actual == expected}
  defp evaluate(actual, "!=", expected), do: {:ok, actual != expected}
  defp evaluate(_actual, operator, _expected), do: {:error, "unsupported operator: #{operator}"}
end
