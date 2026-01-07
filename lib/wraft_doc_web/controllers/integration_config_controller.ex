defmodule WraftDocWeb.Api.V1.IntegrationConfigController do
  @moduledoc """
  Controller for managing integration configurations.

  This controller provides endpoints to:
  - List all available and enabled integrations
  - View integration details
  - Get integration configuration details
  - List integrations by category
  """
  use WraftDocWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias WraftDoc.Enterprise.Organisation
  alias WraftDoc.FeatureFlags
  alias WraftDoc.Integrations
  alias WraftDoc.Integrations.Integration
  alias WraftDoc.Integrations.IntegrationConfig
  alias WraftDoc.Repo
  alias WraftDocWeb.Schemas

  plug WraftDocWeb.Plug.AddActionLog

  tags(["Integrations"])

  operation(:index,
    summary: "List all integrations",
    description:
      "Returns a list of all available integrations with their configuration status for the current organization",
    responses: [
      ok: {"Success", "application/json", Schemas.IntegrationConfig.IntegrationList},
      bad_request: {"Bad Request", "application/json", Schemas.Error},
      forbidden: {"Unauthorized", "application/json", Schemas.Error},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Schemas.Error}
    ]
  )

  @doc """
  Lists all available integrations with their configuration status.

  Returns all possible integrations that can be configured in the system,
  along with information about whether each integration is enabled for
  the current organization and its configuration details.
  """
  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, _params) do
    current_user = conn.assigns.current_user

    feature_flag =
      Organisation
      |> Repo.get(current_user.current_org_id)
      |> then(&FeatureFlags.enabled?(:repository, &1))

    available_integrations = IntegrationConfig.available_integrations()

    enabled_integrations_list = Integrations.list_organisation_integrations(current_user)

    enabled_integrations =
      enabled_integrations_list
      |> Enum.map(&{&1.provider, &1})
      |> Map.new()

    integrations_with_status =
      available_integrations
      |> Enum.map(fn {provider, config} ->
        enabled_integration = Map.get(enabled_integrations, provider)

        {provider,
         Map.merge(
           config,
           if enabled_integration && feature_flag do
             %{
               enabled: enabled_integration.enabled,
               id: enabled_integration.id,
               selected_events: enabled_integration.events,
               config: enabled_integration.config
             }
           else
             %{
               enabled: false,
               id: nil,
               selected_events: [],
               config: %{}
             }
           end
         )}
      end)
      |> Map.new()

    render(conn, "index.json", integrations: integrations_with_status)
  end

  operation(:show,
    summary: "Get integration details",
    description: "Returns details about a specific integration and its configuration status",
    parameters: [
      id: [
        in: :path,
        type: :string,
        description: "Integration provider identifier",
        required: true
      ]
    ],
    responses: [
      ok: {"Success", "application/json", Schemas.IntegrationConfig.Integration},
      bad_request: {"Bad Request", "application/json", Schemas.Error},
      forbidden: {"Unauthorized", "application/json", Schemas.Error},
      not_found: {"Integration provider not found", "application/json", Schemas.Error},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Schemas.Error}
    ]
  )

  @doc """
  Shows details for a specific integration.

  Returns the integration configuration, status, and metadata for a specific provider.
  If the integration is enabled for the current organization, includes the current
  configuration values (with sensitive data masked) and selected events.
  """
  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, %{"id" => provider}) do
    organisation_id = conn.assigns.current_user.current_org_id

    with config when not is_nil(config) <- IntegrationConfig.get_integration_config(provider),
         %Integration{} = integration <-
           Integrations.get_integration_by_provider(organisation_id, provider) do
      config_with_status =
        Map.merge(
          config,
          if integration do
            %{
              enabled: true,
              id: integration.id,
              selected_events: integration.events,
              config: integration.config
            }
          else
            %{
              enabled: false,
              id: nil,
              selected_events: [],
              config: %{}
            }
          end
        )

      render(conn, "show.json", integration: {provider, config_with_status})
    else
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Integration provider not found"})

      error ->
        error
    end
  end

  operation(:categories,
    summary: "List integration categories",
    description: "Returns all integration categories with their associated integrations",
    responses: [
      ok: {"Success", "application/json", Schemas.IntegrationConfig.CategoryList},
      bad_request: {"Bad Request", "application/json", Schemas.Error},
      forbidden: {"Unauthorized", "application/json", Schemas.Error},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Schemas.Error}
    ]
  )

  @doc """
  Lists all integration categories with their associated integrations.

  Groups available integrations by their categories and returns a list of categories,
  each containing its associated integrations with their configuration status.
  """
  @spec categories(Plug.Conn.t(), map()) :: Plug.Conn.t()
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

  operation(:config,
    summary: "Get integration configuration details",
    description: "Returns the detailed configuration for a specific integration",
    parameters: [
      provider: [
        in: :path,
        type: :string,
        description: "Integration provider identifier",
        required: true
      ]
    ],
    responses: [
      ok: {"Success", "application/json", Schemas.IntegrationConfig.ConfigDetails},
      bad_request: {"Bad Request", "application/json", Schemas.Error},
      not_found: {"Integration provider not found", "application/json", Schemas.Error},
      forbidden: {"Unauthorized", "application/json", Schemas.Error}
    ]
  )

  @doc """
  Gets detailed configuration for a specific integration.

  Returns the current configuration values and structure for an integration
  that has been enabled for the current organization. Sensitive data in the
  configuration is masked for security.
  """
  @spec config(Plug.Conn.t(), %{required(String.t()) => String.t()}) :: Plug.Conn.t()
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
