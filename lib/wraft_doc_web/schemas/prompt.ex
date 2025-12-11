defmodule WraftDocWeb.Schemas.Prompt do
  @moduledoc """
  Schema for Prompt request and response
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

  defmodule Prompt do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Prompt",
      description: "An AI prompt",
      type: :object,
      properties: %{
        id: %Schema{type: :string, description: "Prompt ID"},
        title: %Schema{type: :string, description: "Title of the prompt"},
        prompt: %Schema{type: :string, description: "The prompt text"},
        status: %Schema{type: :string, description: "Status of the prompt"},
        type: %Schema{
          type: :string,
          description: "Type of prompt (extraction, suggestion, refinement)"
        },
        model_id: %Schema{type: :string, description: "Associated AI model ID"},
        creator_id: %Schema{type: :string, description: "Creator user ID"},
        organisation_id: %Schema{type: :string, description: "Organisation ID"},
        inserted_at: %Schema{
          type: :string,
          description: "When was the prompt created",
          format: "ISO-8601"
        },
        updated_at: %Schema{
          type: :string,
          description: "When was the prompt last updated",
          format: "ISO-8601"
        }
      },
      required: [:id, :title, :prompt, :status, :type],
      example: %{
        id: "123e4567-e89b-12d3-a456-426614174000",
        title: "Extract Invoice Data",
        prompt: "Extract the invoice number, date, and total amount from this document.",
        status: "active",
        type: "extraction",
        model_id: "model-123",
        creator_id: "user-456",
        organisation_id: "org-789",
        inserted_at: "2023-01-01T12:00:00Z",
        updated_at: "2023-01-01T12:00:00Z"
      }
    })
  end

  defmodule PromptRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Prompt Request",
      description: "Request body for creating or updating a prompt",
      type: :object,
      properties: %{
        title: %Schema{type: :string, description: "Title of the prompt"},
        prompt: %Schema{type: :string, description: "The prompt text"},
        status: %Schema{type: :string, description: "Status of the prompt"},
        type: %Schema{
          type: :string,
          description: "Type of prompt (extraction, suggestion, refinement)"
        }
      },
      required: [:title, :prompt, :status, :type],
      example: %{
        title: "Enhancement",
        prompt: "Enhance the document with additional information",
        status: "active",
        type: "extraction"
      }
    })
  end

  defmodule Prompts do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Prompts List",
      description: "List of prompts",
      type: :array,
      items: Prompt
    })
  end
end
