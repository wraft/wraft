defmodule WraftDoc.Workflows.Adaptors.FormAdaptor do
  @moduledoc """
  Form adaptor for handling form submissions and triggering workflows.

  This adaptor primarily acts as a listener/trigger mechanism rather than
  executing an action. Forms can trigger workflows, and this adaptor processes
  the form data and maps it to workflow inputs.

  Configuration:
  - form_id: String (required) - Form ID to listen for
  - service_mapping: Map (optional) - Maps form fields to workflow input fields
    - Format: %{"form_field" => "workflow_field"}
  - field_mapping: Map (optional) - Same as service_mapping (alias)

  Example:
  config: %{
    "form_id" => "proposal-form",
    "service_mapping" => %{
      "customer_name" => "customer",
      "selected_services" => "services",
      "total_amount" => "amount"
    }
  }
  input_data: %{"form_data" => %{"customer_name" => "Acme", "selected_services" => ["service1"]}}
  output: {:ok, %{"customer" => "Acme", "services" => ["service1"], "amount" => 1000}}
  """

  @behaviour WraftDoc.Workflows.Adaptors.Adaptor

  alias WraftDoc.Forms.Form
  alias WraftDoc.Repo

  require Logger

  @impl true
  def execute(config, input_data, _credentials) do
    with {:ok, form_id} <- get_form_id(config),
         {:ok, form_data} <- get_form_data(input_data),
         {:ok, mapping} <- get_field_mapping(config) do
      Logger.info("[FormAdaptor] Processing form submission for form_id: #{form_id}")

      # Load form to map field IDs -> names for friendly keys and expose registry
      form =
        Form
        |> Repo.get(form_id)
        |> Repo.preload(form_fields: [:field])

      id_to_name = build_id_to_name_map(form)
      available_fields = build_available_fields(form)

      # Map form fields to workflow fields
      mapped_data =
        form_data
        |> map_ids_to_names(id_to_name)
        |> then(fn named_data ->
          # If a custom mapping is provided, apply on top of named data
          case mapping do
            m when map_size(m) > 0 -> apply_field_mapping(named_data, m)
            _ -> named_data
          end
        end)

      # Add form metadata
      output =
        Map.merge(mapped_data, %{
          form_id: form_id,
          submitted_at: DateTime.to_iso8601(DateTime.utc_now()),
          raw_form_data: form_data,
          fields_by_id: form_data,
          fields_by_name: map_ids_to_names(form_data, id_to_name),
          __form_fields__: available_fields
        })

      Logger.info("[FormAdaptor] Form data processed successfully")
      {:ok, output}
    end
  end

  @impl true
  def validate_config(config) do
    cond do
      !Map.has_key?(config, "form_id") -> {:error, "form_id is required"}
      !is_binary(config["form_id"]) -> {:error, "form_id must be a string"}
      true -> :ok
    end
  end

  defp get_form_id(config) do
    case Map.get(config, "form_id") do
      nil -> {:error, "form_id is required"}
      form_id when is_binary(form_id) -> {:ok, form_id}
      _ -> {:error, "form_id must be a string"}
    end
  end

  defp get_form_data(input_data) do
    # Form data can come in different formats:
    # 1. Direct form_data key
    # 2. As root-level data
    form_data =
      Map.get(input_data, "form_data") ||
        Map.get(input_data, "data") ||
        input_data

    if is_map(form_data) do
      {:ok, form_data}
    else
      {:error, "form_data must be a map"}
    end
  end

  defp get_field_mapping(config) do
    mapping =
      Map.get(config, "service_mapping") ||
        Map.get(config, "field_mapping") ||
        Map.get(config, "mapping") ||
        %{}

    if is_map(mapping) do
      {:ok, mapping}
    else
      {:error, "service_mapping must be a map"}
    end
  end

  defp apply_field_mapping(form_data, mapping) when map_size(mapping) == 0 do
    # No mapping, return form data as-is
    form_data
  end

  defp apply_field_mapping(form_data, mapping) do
    # Apply field mapping
    Enum.reduce(mapping, %{}, fn {form_field, workflow_field}, acc ->
      value =
        get_nested_value(form_data, form_field) ||
          Map.get(form_data, form_field) ||
          Map.get(form_data, String.to_atom(form_field))

      if value != nil do
        Map.put(acc, workflow_field, value)
      else
        acc
      end
    end)
  end

  defp get_nested_value(map, path) when is_map(map) and is_binary(path) do
    # Support dot notation for nested fields (e.g., "customer.name")
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

  defp build_id_to_name_map(nil), do: %{}

  defp build_id_to_name_map(%Form{form_fields: form_fields}) do
    Enum.reduce(form_fields, %{}, fn ff, acc ->
      case ff.field do
        %{id: field_id, name: name} when is_binary(field_id) and is_binary(name) ->
          Map.put(acc, field_id, name)

        _ ->
          acc
      end
    end)
  end

  defp map_ids_to_names(map, id_to_name) when is_map(map) do
    Enum.reduce(map, %{}, fn {k, v}, acc ->
      key_str = to_string(k)
      new_key = Map.get(id_to_name, key_str, key_str)
      Map.put(acc, new_key, v)
    end)
  end

  defp build_available_fields(nil), do: []

  defp build_available_fields(%Form{form_fields: form_fields}) do
    Enum.map(form_fields, fn ff ->
      %{
        id: ff.field_id,
        name: ff.field && ff.field.name,
        type: ff.field && ff.field.field_type_id
      }
    end)
  end
end
