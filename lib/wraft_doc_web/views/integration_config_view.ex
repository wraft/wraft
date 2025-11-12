defmodule WraftDocWeb.Api.V1.IntegrationConfigView do
  use WraftDocWeb, :view

  def render("index.json", %{integrations: integrations}) do
    render_many(integrations, __MODULE__, "integration_config.json", as: :integration)
  end

  def render("show.json", %{integration: integration}) do
    render_one(integration, __MODULE__, "integration_config.json", as: :integration)
  end

  def render("categories.json", %{categories: categories}) do
    render_many(categories, __MODULE__, "category.json", as: :category)
  end

  def render("config.json", %{
        provider: provider,
        config: config,
        config_structure: config_structure
      }) do
    %{
      provider: provider,
      config: sanitize_config(config, config_structure),
      config_structure: sanitize_config_structure(config_structure)
    }
  end

  def render("integration_config.json", %{integration: {provider, config}}) do
    %{
      provider: provider,
      name: config.name,
      category: config.category,
      description: config.description,
      icon: config.icon,
      enabled: config.enabled,
      id: config.id,
      config_structure: sanitize_config_structure(config.config_structure),
      available_events: config.available_events,
      selected_events: config.selected_events,
      config: sanitize_config(config.config, config.config_structure)
    }
  end

  def render("category.json", %{category: category}) do
    %{
      category: category.category,
      integrations:
        Enum.map(category.integrations, fn integration ->
          %{
            provider: integration.provider,
            name: integration.name,
            description: integration.description,
            icon: integration.icon,
            enabled: integration.enabled,
            id: integration.id,
            config_structure: sanitize_config_structure(integration.config_structure),
            available_events: integration.available_events,
            selected_events: integration.selected_events,
            config: sanitize_config(integration.config, integration.config_structure)
          }
        end)
    }
  end

  # Remove sensitive information from config structure
  defp sanitize_config_structure(config_structure) do
    config_structure
    |> Enum.map(fn {key, field} ->
      # Never send actual values to frontend
      {key, Map.put(field, :value, nil)}
    end)
    |> Map.new()
  end

  # Sanitize config values to hide sensitive data
  defp sanitize_config(config_values, config_structure) do
    config_values
    |> Enum.map(fn {key, value} -> sanitize_config_value(key, value, config_structure) end)
    |> Map.new()
  end

  defp sanitize_config_value(key, value, config_structure) do
    atom_key = if is_binary(key), do: String.to_existing_atom(key), else: key
    field_config = Map.get(config_structure, atom_key, %{})

    if Map.get(field_config, :secret, false) do
      {key, format_secret_value(value)}
    else
      {key, value}
    end
  end

  defp format_secret_value(value) when is_binary(value) and byte_size(value) >= 2 do
    "****************#{String.slice(value, -2..-1)}"
  end

  defp format_secret_value(_value) do
    "******************"
  end
end
