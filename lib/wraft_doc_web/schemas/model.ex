defmodule WraftDocWeb.Schemas.Model do
  @moduledoc """
  Schema for Model request and response
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

  defmodule ModelRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Model Request",
      description: "Request body for creating or updating a model",
      type: :object,
      properties: %{
        name: %Schema{type: :string, description: "Name of the model"},
        description: %Schema{type: :string, description: "Description of the model"},
        provider: %Schema{type: :string, description: "AI provider (e.g., OpenAI, Anthropic)"},
        endpoint_url: %Schema{type: :string, description: "API endpoint URL"},
        is_default: %Schema{type: :boolean, description: "Whether this is the default model"},
        is_local: %Schema{type: :boolean, description: "Whether the model is hosted locally"},
        is_thinking_model: %Schema{
          type: :boolean,
          description: "Whether this is a thinking/reasoning model"
        },
        daily_request_limit: %Schema{type: :integer, description: "Daily request limit"},
        daily_token_limit: %Schema{type: :integer, description: "Daily token limit"},
        auth_key: %Schema{type: :string, description: "Authentication key for the model"},
        status: %Schema{type: :string, description: "Status of the model"},
        model_name: %Schema{type: :string, description: "Technical model name"},
        model_type: %Schema{type: :string, description: "Type of model"},
        model_version: %Schema{type: :string, description: "Version of the model"}
      },
      required: [
        :name,
        :description,
        :provider,
        :endpoint_url,
        :is_local,
        :is_thinking_model,
        :daily_request_limit,
        :daily_token_limit,
        :auth_key,
        :status,
        :model_name,
        :model_type,
        :model_version
      ],
      example: %{
        name: "GPT-4 Model",
        description: "OpenAI GPT-4 model for text generation",
        provider: "OpenAI",
        endpoint_url: "https://api.openai.com/v1/chat/completions",
        is_local: false,
        is_thinking_model: false,
        daily_request_limit: 1000,
        daily_token_limit: 100_000,
        auth_key: "sk-...",
        status: "active",
        model_name: "gpt-4",
        model_type: "chat",
        model_version: "0613"
      }
    })
  end

  defmodule Model do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "AI Model",
      description: "An AI model configuration",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "Model ID"},
        name: %Schema{type: :string, description: "Name of the model"},
        description: %Schema{type: :string, description: "Description of the model"},
        provider: %Schema{type: :string, description: "AI provider (e.g., OpenAI, Anthropic)"},
        endpoint_url: %Schema{type: :string, description: "API endpoint URL"},
        is_local: %Schema{type: :boolean, description: "Whether the model is hosted locally"},
        is_thinking_model: %Schema{
          type: :boolean,
          description: "Whether this is a thinking/reasoning model"
        },
        daily_request_limit: %Schema{type: :integer, description: "Daily request limit"},
        daily_token_limit: %Schema{type: :integer, description: "Daily token limit"},
        status: %Schema{type: :string, description: "Status of the model"},
        model_name: %Schema{type: :string, description: "Technical model name"},
        model_type: %Schema{type: :string, description: "Type of model"},
        model_version: %Schema{type: :string, description: "Version of the model"},
        creator_id: %Schema{type: :string, description: "Creator user ID"},
        organisation_id: %Schema{type: :string, description: "Organisation ID"},
        inserted_at: %Schema{
          type: :string,
          description: "When was the model created",
          format: "ISO-8601"
        },
        updated_at: %Schema{
          type: :string,
          description: "When was the model last updated",
          format: "ISO-8601"
        }
      },
      required: [
        :id,
        :name,
        :description,
        :provider,
        :endpoint_url,
        :is_local,
        :is_thinking_model,
        :daily_request_limit,
        :daily_token_limit,
        :status,
        :model_name,
        :model_type,
        :model_version
      ],
      example: %{
        id: "123e4567-e89b-12d3-a456-426614174000",
        name: "GPT-4 Model",
        description: "OpenAI GPT-4 model for text generation",
        provider: "OpenAI",
        endpoint_url: "https://api.openai.com/v1/chat/completions",
        is_local: false,
        is_thinking_model: false,
        daily_request_limit: 1000,
        daily_token_limit: 100_000,
        status: "active",
        model_name: "gpt-4",
        model_type: "chat",
        model_version: "0613",
        creator_id: "user-456",
        organisation_id: "org-789",
        inserted_at: "2023-01-01T12:00:00Z",
        updated_at: "2023-01-01T12:00:00Z"
      }
    })
  end

  defmodule Models do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Models List",
      description: "List of AI models",
      type: :array,
      items: Model
    })
  end
end
