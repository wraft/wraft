defmodule WraftDocWeb.Schemas.IntegrationConfig do
  @moduledoc """
  Schema for IntegrationConfig request and response
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

  defmodule Integration do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Integration",
      description: "Details about an integration and its configuration",
      type: :object,
      properties: %{
        provider: %Schema{
          type: :string,
          description: "Unique identifier for the integration provider"
        },
        name: %Schema{type: :string, description: "Display name of the integration"},
        category: %Schema{type: :string, description: "Category the integration belongs to"},
        description: %Schema{
          type: :string,
          description: "Description of the integration's functionality"
        },
        icon: %Schema{type: :string, description: "Icon identifier for the integration"},
        enabled: %Schema{
          type: :boolean,
          description: "Whether the integration is enabled for the organization"
        },
        id: %Schema{
          type: :string,
          description: "ID of the enabled integration configuration (null if not enabled)"
        },
        config_structure: %Schema{
          type: :object,
          description: "Structure of configuration fields for the integration"
        },
        available_events: %Schema{
          type: :array,
          items: %Schema{type: :object},
          description: "List of events the integration can subscribe to"
        },
        selected_events: %Schema{
          type: :array,
          items: %Schema{type: :string},
          description: "List of events the organization has subscribed to"
        },
        config: %Schema{
          type: :object,
          description: "Current configuration values (with sensitive data masked)"
        }
      },
      required: [:provider, :name, :category, :description, :icon, :enabled],
      example: %{
        provider: "slack",
        name: "Slack",
        category: "communication",
        description: "Integrate with Slack for notifications and updates",
        icon: "slack-icon",
        enabled: true,
        id: "3fa85f64-5717-4562-b3fc-2c963f66afa6",
        config_structure: %{
          bot_token: %{
            type: "string",
            label: "Bot Token",
            description: "Slack Bot User OAuth Token",
            required: true
          }
        },
        available_events: ["document.signed"],
        selected_events: ["document.signed"]
      }
    })
  end

  defmodule IntegrationList do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Integration List",
      description: "List of all available integrations with their configuration status",
      type: :array,
      items: Integration,
      example: [
        %{
          provider: "slack",
          name: "Slack",
          category: "communication",
          description: "Integrate with Slack for notifications and updates",
          icon: "slack-icon",
          enabled: true,
          id: "3fa85f64-5717-4562-b3fc-2c963f66afa6",
          config_structure: %{
            bot_token: %{
              type: "string",
              label: "Bot Token",
              description: "Slack Bot User OAuth Token",
              required: true
            }
          },
          available_events: ["document.signed"],
          selected_events: ["document.signed"]
        }
      ]
    })
  end

  defmodule Category do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Integration Category",
      description: "Category of integrations with the list of integrations in that category",
      type: :object,
      properties: %{
        category: %Schema{type: :string, description: "Name of the category"},
        integrations: %Schema{
          type: :array,
          items: Integration,
          description: "List of integrations in this category"
        }
      },
      required: [:category, :integrations],
      example: %{
        category: "communication",
        integrations: [
          %{
            provider: "slack",
            name: "Slack",
            description: "Integrate with Slack for notifications",
            enabled: true,
            id: "3fa85f64-5717-4562-b3fc-2c963f66afa6",
            config_structure: %{
              bot_token: %{
                type: "string",
                label: "Bot Token",
                description: "Slack Bot User OAuth Token",
                required: true
              }
            },
            available_events: ["document.signed"],
            selected_events: ["document.signed"]
          }
        ]
      }
    })
  end

  defmodule CategoryList do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Integration Categories List",
      description: "List of integration categories with their associated integrations",
      type: :array,
      items: Category,
      example: [
        %{
          category: "communication",
          integrations: [
            %{
              provider: "slack",
              name: "Slack",
              description: "Integrate with Slack for notifications",
              enabled: true,
              id: "3fa85f64-5717-4562-b3fc-2c963f66afa6",
              config_structure: %{
                bot_token: %{
                  type: "string",
                  label: "Bot Token",
                  description: "Slack Bot User OAuth Token",
                  required: true
                }
              },
              available_events: ["document.signed"],
              selected_events: ["document.signed"]
            }
          ]
        }
      ]
    })
  end

  defmodule ConfigDetails do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Integration Configuration Details",
      description: "Detailed configuration for a specific integration",
      type: :object,
      properties: %{
        provider: %Schema{type: :string, description: "Integration provider identifier"},
        config: %Schema{
          type: :object,
          description: "Current configuration values (with sensitive data masked)"
        },
        config_structure: %Schema{
          type: :object,
          description: "Structure and metadata for configuration fields"
        }
      },
      required: [:provider, :config, :config_structure],
      example: %{
        provider: "slack",
        config: %{"bot_token" => "xoxb-1234567890-abcdefghij"},
        config_structure: %{
          bot_token: %{
            type: "string",
            label: "Bot Token",
            description: "Slack Bot User OAuth Token",
            required: true
          }
        }
      }
    })
  end
end
