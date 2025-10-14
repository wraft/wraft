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
  use PhoenixSwagger

  alias WraftDoc.Integrations
  alias WraftDoc.Integrations.IntegrationConfig

  plug WraftDocWeb.Plug.AddActionLog
  plug WraftDocWeb.Plug.FeatureFlagCheck, feature: :repository

  def swagger_definitions do
    %{
      IntegrationList:
        swagger_schema do
          title("Integration List")
          description("List of all available integrations with their configuration status")
          type(:array)
          items(Schema.ref(:Integration))
        end,
      Integration:
        swagger_schema do
          title("Integration")
          description("Details about an integration and its configuration")

          properties do
            provider(:string, "Unique identifier for the integration provider", required: true)
            name(:string, "Display name of the integration", required: true)
            category(:string, "Category the integration belongs to", required: true)
            description(:string, "Description of the integration's functionality", required: true)
            icon(:string, "Icon identifier for the integration", required: true)

            enabled(:boolean, "Whether the integration is enabled for the organization",
              required: true
            )

            id(:string, "ID of the enabled integration configuration (null if not enabled)")
            config_structure(:object, "Structure of configuration fields for the integration")
            available_events(:array, "List of events the integration can subscribe to")
            selected_events(:array, "List of events the organization has subscribed to")
            config(:object, "Current configuration values (with sensitive data masked)")
          end

          example(%{
            provider: "slack",
            name: "Slack",
            category: "communication",
            description: "Integrate with Slack for notifications and updates",
            icon: "slack-icon",
            enabled: true,
            id: "123e4567-e89b-12d3-a456-426614174000",
            config_structure: %{
              bot_token: %{
                type: "string",
                label: "Bot Token",
                description: "Slack Bot User OAuth Token",
                required: true
              }
            },
            available_events: [
              %{id: "document.signed", name: "Document Signed"}
            ],
            selected_events: ["document.signed"]
          })
        end,
      CategoryList:
        swagger_schema do
          title("Integration Categories List")
          description("List of integration categories with their associated integrations")
          type(:array)
          items(Schema.ref(:Category))
        end,
      Category:
        swagger_schema do
          title("Integration Category")
          description("Category of integrations with the list of integrations in that category")

          properties do
            category(:string, "Name of the category", required: true)

            integrations(:array, "List of integrations in this category",
              required: true,
              items: Schema.ref(:Integration)
            )
          end

          example(%{
            category: "communication",
            integrations: [
              %{
                provider: "slack",
                name: "Slack",
                description: "Integrate with Slack for notifications",
                enabled: true
              }
            ]
          })
        end,
      ConfigDetails:
        swagger_schema do
          title("Integration Configuration Details")
          description("Detailed configuration for a specific integration")

          properties do
            provider(:string, "Integration provider identifier", required: true)

            config(:object, "Current configuration values (with sensitive data masked)",
              required: true
            )

            config_structure(:object, "Structure and metadata for configuration fields",
              required: true
            )
          end
        end,
      Error:
        swagger_schema do
          title("Error")
          description("Error response")

          properties do
            error(:string, "Error message describing what went wrong", required: true)
          end

          example(%{
            error: "Integration provider not found"
          })
        end
    }
  end

  swagger_path :index do
    get("/configs")
    summary("List all integrations")

    description(
      "Returns a list of all available integrations with their configuration status for the current organization"
    )

    tag("Integrations")

    response(200, "Success", Schema.ref(:IntegrationList))
    response(400, "Bad Request", Schema.ref(:Error))
    response(403, "Unauthorized", Schema.ref(:Error))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
  end

  @doc """
  Lists all available integrations with their configuration status.

  Returns all possible integrations that can be configured in the system,
  along with information about whether each integration is enabled for
  the current organization and its configuration details.
  """
  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, _params) do
    current_user = conn.assigns.current_user
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

  swagger_path :show do
    get("/configs/{id}")
    summary("Get integration details")
    description("Returns details about a specific integration and its configuration status")

    parameters do
      id(:path, :string, "Integration provider identifier", required: true)
    end

    tag("Integrations")

    response(200, "Success", Schema.ref(:Integration))
    response(400, "Bad Request", Schema.ref(:Error))
    response(403, "Unauthorized", Schema.ref(:Error))
    response(404, "Integration provider not found", Schema.ref(:Error))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
  end

  @doc """
  Shows details for a specific integration.

  Returns the integration configuration, status, and metadata for a specific provider.
  If the integration is enabled for the current organization, includes the current
  configuration values (with sensitive data masked) and selected events.
  """
  @spec show(Plug.Conn.t(), %{required(String.t()) => String.t()}) :: Plug.Conn.t()
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

  swagger_path :categories do
    get("/configs/categories")
    summary("List integration categories")
    description("Returns all integration categories with their associated integrations")

    tag("Integrations")

    response(200, "Success", Schema.ref(:CategoryList))
    response(400, "Bad Request", Schema.ref(:Error))
    response(403, "Unauthorized", Schema.ref(:Error))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
  end

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

  swagger_path :config do
    get("/{provider}/config")
    summary("Get integration configuration details")
    description("Returns the detailed configuration for a specific integration")

    parameters do
      provider(:path, :string, "Integration provider identifier", required: true)
    end

    tag("Integrations")

    response(200, "Success", Schema.ref(:ConfigDetails))
    response(400, "Bad Request", Schema.ref(:Error))
    response(404, "Integration provider not found", Schema.ref(:Error))
    response(404, "Integration not configured for this organization", Schema.ref(:Error))
    response(403, "Unauthorized", Schema.ref(:Error))
  end

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
