defmodule WraftDocWeb.Api.V1.IntegrationConfigController do
  use WraftDocWeb, :controller
  alias WraftDoc.Integrations
  alias WraftDoc.Integrations.IntegrationConfig

  plug WraftDocWeb.Plug.AddActionLog
  plug WraftDocWeb.Plug.FeatureFlagCheck, feature: :repository

  def index(conn, _params) do
    available_integrations = IntegrationConfig.available_integrations()
    organisation_id = conn.assigns.current_user.current_org_id

    enabled_integrations_list = Integrations.list_organisation_integrations(organisation_id)

    enabled_integrations =
      enabled_integrations_list
      |> Enum.map(&{&1.provider, &1})
      |> Map.new()

    integrations_with_status =
      available_integrations
      |> Enum.map(fn {provider, config} ->
        enabled_integration = Map.get(enabled_integrations, provider)

        {provider,
         Map.merge(config, %{
           enabled: if(enabled_integration, do: enabled_integration.enabled, else: false),
           id: if(enabled_integration, do: enabled_integration.id, else: nil),
           selected_events: if(enabled_integration, do: enabled_integration.events, else: []),
           config: if(enabled_integration, do: enabled_integration.config, else: %{})
         })}
      end)
      |> Map.new()

    render(conn, "index.json", integrations: integrations_with_status)
  end

  def show(conn, %{"id" => provider}) do
    case IntegrationConfig.get_integration_config(provider) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Integration provider not found"})

      config ->
        organisation_id = conn.assigns.current_user.current_org_id
        integration = Integrations.get_integration_by_provider(organisation_id, provider)

        config_with_status =
          Map.merge(config, %{
            enabled: not is_nil(integration),
            id: if(integration, do: integration.id, else: nil),
            selected_events: if(integration, do: integration.events, else: []),
            config: if(integration, do: integration.config, else: %{})
          })

        render(conn, "show.json", integration: {provider, config_with_status})
    end
  end

  def categories(conn, _params) do
    categories = IntegrationConfig.list_categories_with_integrations()
    organisation_id = conn.assigns.current_user.current_org_id

    enabled_integrations_list = Integrations.list_organisation_integrations(organisation_id)

    enabled_integrations =
      enabled_integrations_list
      |> Enum.map(&{&1.provider, &1})
      |> Map.new()

    categories_with_status =
      Enum.map(categories, fn category ->
        integrations =
          Enum.map(category.integrations, fn integration ->
            enabled_integration = Map.get(enabled_integrations, integration.provider)

            Map.merge(integration, %{
              enabled: not is_nil(enabled_integration),
              id: if(enabled_integration, do: enabled_integration.id, else: nil),
              selected_events: if(enabled_integration, do: enabled_integration.events, else: []),
              config: if(enabled_integration, do: enabled_integration.config, else: %{})
            })
          end)

        Map.put(category, :integrations, integrations)
      end)

    render(conn, "categories.json", categories: categories_with_status)
  end

  def config(conn, %{"provider" => provider}) do
    case IntegrationConfig.get_integration_config(provider) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Integration provider not found"})

      config ->
        organisation_id = conn.assigns.current_user.current_org_id
        integration = Integrations.get_integration_by_provider(organisation_id, provider)

        case integration do
          nil ->
            conn
            |> put_status(:not_found)
            |> json(%{error: "Integration not configured for this organization"})

          integration ->
            render(conn, "config.json", %{
              provider: provider,
              config: integration.config,
              config_structure: config.config_structure
            })
        end
    end
  end
end
