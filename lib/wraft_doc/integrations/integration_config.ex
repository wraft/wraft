defmodule WraftDoc.Integrations.IntegrationConfig do
  @moduledoc """
  Defines the configuration structure and metadata for all supported integrations.
  """

  @doc """
  Returns the configuration structure for all supported integrations.
  This is used to inform the frontend about the required fields and their types.
  """
  def available_integrations do
    %{
      "slack" => %{
        name: "Slack",
        category: "communication",
        description: "Integrate with Slack for notifications and updates",
        # Frontend can map this to an actual icon
        icon: "slack-icon",
        config_structure: %{
          bot_token: %{
            type: "string",
            label: "Bot Token",
            description: "Slack Bot User OAuth Token",
            required: true,
            secret: true
          },
          signing_secret: %{
            type: "string",
            label: "Signing Secret",
            description: "Slack Signing Secret for verifying requests",
            required: true,
            secret: true
          }
        },
        available_events: [
          %{
            id: "document.signed",
            name: "Document Signed",
            description: "Triggered when a document is signed"
          },
          %{
            id: "document.created",
            name: "Document Created",
            description: "Triggered when a new document is created"
          }
        ]
      },
      "docusign" => %{
        name: "DocuSign",
        category: "document_management",
        description: "Electronic signature and document management",
        icon: "docusign-icon",
        config_structure: %{
          client_id: %{
            type: "string",
            label: "Client ID",
            description: "DocuSign Integration Key (Client ID)",
            required: true,
            secret: true
          },
          client_secret: %{
            type: "string",
            label: "Client Secret",
            description: "DocuSign Client Secret",
            required: true,
            secret: true
          },
          redirect_uri: %{
            type: "string",
            label: "Redirect URI",
            description: "OAuth2 Redirect URI",
            required: true,
            secret: false
          }
        },
        available_events: [
          %{
            id: "envelope.signed",
            name: "Envelope Signed",
            description: "Triggered when an envelope is signed"
          },
          %{
            id: "envelope.sent",
            name: "Envelope Sent",
            description: "Triggered when an envelope is sent"
          }
        ]
      },
      "okta" => %{
        name: "Okta",
        category: "authentication",
        description: "Enterprise identity and access management",
        icon: "okta-icon",
        config_structure: %{
          domain: %{
            type: "string",
            label: "Okta Domain",
            description: "Your Okta domain (e.g., company.okta.com)",
            required: true,
            secret: false
          },
          api_token: %{
            type: "string",
            label: "API Token",
            description: "Okta API Token",
            required: true,
            secret: true
          },
          client_id: %{
            type: "string",
            label: "Client ID",
            description: "OAuth2 Client ID",
            required: true,
            secret: true
          },
          client_secret: %{
            type: "string",
            label: "Client Secret",
            description: "OAuth2 Client Secret",
            required: true,
            secret: true
          }
        },
        available_events: [
          %{
            id: "user.created",
            name: "User Created",
            description: "Triggered when a new user is created"
          },
          %{
            id: "user.deactivated",
            name: "User Deactivated",
            description: "Triggered when a user is deactivated"
          }
        ]
      },
      "zapier" => %{
        name: "Zapier",
        category: "automation",
        description: "Automate workflows with Zapier",
        icon: "zapier-icon",
        config_structure: %{
          webhook_url: %{
            type: "string",
            label: "Webhook URL",
            description: "Zapier Webhook URL",
            required: true,
            secret: true
          },
          api_key: %{
            type: "string",
            label: "API Key",
            description: "API Key for authentication",
            required: true,
            secret: true
          }
        },
        available_events: [
          %{
            id: "document.created",
            name: "Document Created",
            description: "Triggered when a new document is created"
          },
          %{
            id: "document.updated",
            name: "Document Updated",
            description: "Triggered when a document is updated"
          },
          %{
            id: "document.signed",
            name: "Document Signed",
            description: "Triggered when a document is signed"
          }
        ]
      }
    }
  end

  @doc """
  Returns the configuration structure for a specific integration.
  """
  def get_integration_config(provider) do
    Map.get(available_integrations(), provider)
  end

  @doc """
  Returns a list of all available integration providers.
  """
  def list_providers do
    Map.keys(available_integrations())
  end

  @doc """
  Returns a list of all available categories with their integrations.
  """
  def list_categories_with_integrations do
    available_integrations()
    |> Enum.group_by(fn {_key, config} -> config.category end)
    |> Enum.map(fn {category, integrations} ->
      %{
        category: category,
        integrations:
          Enum.map(integrations, fn {key, config} ->
            Map.put(config, :provider, key)
          end)
      }
    end)
  end
end
