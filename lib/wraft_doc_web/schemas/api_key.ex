defmodule WraftDocWeb.Schemas.ApiKey do
  @moduledoc """
  Schema for API key request and response
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

  defmodule ApiKeyRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "API Key Request",
      description: "Request body to create an API key",
      type: :object,
      required: [:name],
      properties: %{
        name: %Schema{type: :string, description: "Descriptive name for the API key"},
        user_id: %Schema{
          type: :string,
          description: "User ID for authentication (defaults to current user)"
        },
        expires_at: %Schema{
          type: :string,
          description: "Optional: Expiration datetime (ISO-8601)"
        },
        rate_limit: %Schema{type: :integer, description: "Requests per hour limit"},
        ip_whitelist: %Schema{
          type: :array,
          items: %Schema{type: :string},
          description: "Optional: List of allowed IP addresses"
        },
        metadata: %Schema{type: :object, description: "Optional: Custom metadata as JSON"}
      },
      example: %{
        name: "CRM Integration",
        rate_limit: 1000,
        metadata: %{
          integration_type: "salesforce",
          environment: "production"
        }
      }
    })
  end

  defmodule ApiKeyUpdateRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "API Key Update Request",
      description: "Request body to update an API key",
      type: :object,
      properties: %{
        name: %Schema{type: :string, description: "Descriptive name for the API key"},
        expires_at: %Schema{
          type: :string,
          description: "Optional: Expiration datetime (ISO-8601)"
        },
        rate_limit: %Schema{type: :integer, description: "Requests per hour limit"},
        ip_whitelist: %Schema{
          type: :array,
          items: %Schema{type: :string},
          description: "Optional: List of allowed IP addresses"
        },
        is_active: %Schema{type: :boolean, description: "Enable or disable the key"},
        metadata: %Schema{type: :object, description: "Optional: Custom metadata as JSON"}
      },
      example: %{
        name: "CRM Integration - Updated",
        is_active: true,
        rate_limit: 2000
      }
    })
  end

  defmodule ApiKeyResponse do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "API Key Response",
      description: "API key details",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "API Key ID"},
        name: %Schema{type: :string, description: "API key name"},
        key: %Schema{
          type: :string,
          description: "The actual API key (only shown once during creation)"
        },
        key_prefix: %Schema{type: :string, description: "Key prefix for identification"},
        expires_at: %Schema{type: :string, description: "Expiration datetime"},
        is_active: %Schema{type: :boolean, description: "Whether the key is active"},
        rate_limit: %Schema{type: :integer, description: "Rate limit"},
        ip_whitelist: %Schema{
          type: :array,
          items: %Schema{type: :string},
          description: "IP whitelist"
        },
        last_used_at: %Schema{type: :string, description: "Last usage timestamp"},
        usage_count: %Schema{type: :integer, description: "Total usage count"},
        metadata: %Schema{type: :object, description: "Custom metadata"},
        inserted_at: %Schema{type: :string, description: "Creation timestamp"},
        updated_at: %Schema{type: :string, description: "Last update timestamp"}
      },
      example: %{
        id: "123e4567-e89b-12d3-a456-426614174000",
        name: "CRM Integration",
        key: "wraft_a1b2c3d4_AbCdEfGhIjKlMnOpQrStUvWxYz123456",
        key_prefix: "a1b2c3d4",
        expires_at: nil,
        is_active: true,
        rate_limit: 1000,
        ip_whitelist: [],
        last_used_at: nil,
        usage_count: 0,
        metadata: %{integration_type: "salesforce"},
        inserted_at: "2024-11-18T10:00:00Z",
        updated_at: "2024-11-18T10:00:00Z"
      }
    })
  end

  defmodule ApiKeyIndex do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "API Keys Index",
      description: "List of API keys",
      type: :object,
      properties: %{
        api_keys: %Schema{type: :array, items: ApiKeyResponse},
        page_number: %Schema{type: :integer, description: "Current page number"},
        total_pages: %Schema{type: :integer, description: "Total number of pages"},
        total_entries: %Schema{type: :integer, description: "Total number of API keys"}
      },
      example: %{
        api_keys: [
          %{
            id: "123e4567-e89b-12d3-a456-426614174000",
            name: "CRM Integration",
            key_prefix: "a1b2c3d4",
            is_active: true,
            rate_limit: 1000,
            usage_count: 150,
            last_used_at: "2024-11-18T09:30:00Z"
          }
        ],
        page_number: 1,
        total_pages: 1,
        total_entries: 1
      }
    })
  end
end
