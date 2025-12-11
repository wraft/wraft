defmodule WraftDocWeb.Schemas.Integration do
  @moduledoc """
  Schema for Integration request and response
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

  defmodule Integration do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Integration",
      description: "An integration with an external service",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid, description: "Integration identifier"},
        provider: %Schema{type: :string, description: "Integration provider name"},
        name: %Schema{type: :string, description: "Display name of the integration"},
        category: %Schema{type: :string, description: "Category the integration belongs to"},
        enabled: %Schema{type: :boolean, description: "Whether the integration is enabled"},
        events: %Schema{
          type: :array,
          items: %Schema{type: :string},
          description: "List of events this integration subscribes to"
        },
        metadata: %Schema{type: :object, description: "Additional metadata about the integration"},
        inserted_at: %Schema{
          type: :string,
          format: "date-time",
          description: "When the integration was created"
        },
        updated_at: %Schema{
          type: :string,
          format: "date-time",
          description: "When the integration was last updated"
        }
      },
      required: [:provider, :name, :category, :enabled],
      example: %{
        id: "123e4567-e89b-12d3-a456-426614174000",
        provider: "slack",
        name: "Slack",
        category: "communication",
        enabled: true,
        events: ["document.created", "document.signed"],
        metadata: %{},
        inserted_at: "2023-01-01T12:00:00Z",
        updated_at: "2023-01-01T12:30:00Z"
      }
    })
  end

  defmodule IntegrationResponse do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Integration Response",
      description: "Response containing a single integration",
      type: :object,
      properties: %{
        data: Integration
      }
    })
  end

  defmodule IntegrationsResponse do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Integrations List Response",
      description: "Response containing a list of integrations",
      type: :array,
      items: Integration
    })
  end

  defmodule IntegrationCreateParams do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Integration Create Parameters",
      description: "Parameters for creating a new integration",
      type: :object,
      properties: %{
        provider: %Schema{type: :string, description: "Integration provider identifier"},
        name: %Schema{type: :string, description: "Display name for the integration"},
        category: %Schema{type: :string, description: "Category the integration belongs to"},
        config: %Schema{
          type: :object,
          description: "Configuration parameters for the integration"
        },
        events: %Schema{
          type: :array,
          items: %Schema{type: :string},
          description: "List of events to subscribe to"
        }
      },
      required: [:provider, :name, :category, :config],
      example: %{
        provider: "slack",
        name: "Team Slack",
        category: "communication",
        config: %{
          "bot_token" => "xoxb-1234567890-abcdefghij",
          "signing_secret" => "abcdef1234567890"
        },
        events: ["document.created", "document.signed"]
      }
    })
  end

  defmodule IntegrationUpdateParams do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Integration Update Parameters",
      description: "Parameters for updating an existing integration",
      type: :object,
      properties: %{
        integration: %Schema{
          type: :object,
          description: "Integration parameters to update",
          properties: %{
            name: %Schema{type: :string, description: "Display name for the integration"},
            config: %Schema{type: :object, description: "Configuration parameters"},
            enabled: %Schema{type: :boolean, description: "Whether the integration is enabled"}
          }
        }
      },
      required: [:integration]
    })
  end

  defmodule EventUpdateParams do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Events Update Parameters",
      description: "Parameters for updating integration event subscriptions",
      type: :object,
      properties: %{
        events: %Schema{
          type: :array,
          items: %Schema{type: :string},
          description: "List of events to subscribe to"
        }
      },
      required: [:events],
      example: %{
        events: ["document.created", "document.signed"]
      }
    })
  end
end
