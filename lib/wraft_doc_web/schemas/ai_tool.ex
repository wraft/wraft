defmodule WraftDocWeb.Schemas.AiTool do
  @moduledoc """
  Schema for AI tool request and response
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

  defmodule AiToolRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "AI Tool Request",
      description: "Request body for AI tool execution",
      type: :object,
      required: [:content],
      properties: %{
        model_id: %Schema{
          type: :string,
          description:
            "Model ID (optional - will use organization's default model if not provided)"
        },
        prompt_id: %Schema{
          type: :string,
          description: "Database prompt ID (required if prompt and prompt_type are not provided)"
        },
        prompt: %Schema{
          type: :string,
          description: "Inline prompt text (required if prompt_id is not provided)"
        },
        prompt_type: %Schema{
          type: :string,
          description: "Type of prompt when using inline prompt",
          enum: ["suggestion", "refinement", "extraction"]
        },
        content: %Schema{type: :string, description: "Content to process"}
      },
      example: %{
        model_id: "123e4567-e89b-12d3-a456-426614174000",
        prompt: "Extract key information from this document",
        prompt_type: "extraction",
        content: "This is the document content to be processed..."
      }
    })
  end

  defmodule AiToolResult do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "AI Tool Result",
      description: "Result from AI tool execution",
      type: :object,
      properties: %{
        entities: %Schema{
          type: :object,
          description: "Extraction result - extracted entities",
          properties: %{
            people: %Schema{
              type: :array,
              items: %Schema{type: :string},
              description: "Names of people mentioned"
            },
            companies: %Schema{
              type: :array,
              items: %Schema{type: :string},
              description: "Company names mentioned"
            },
            government_bodies: %Schema{
              type: :array,
              items: %Schema{type: :string},
              description: "Government organizations mentioned"
            },
            courts: %Schema{
              type: :array,
              items: %Schema{type: :string},
              description: "Courts mentioned"
            }
          }
        },
        dates: %Schema{
          type: :array,
          description: "Extraction result - important dates",
          items: %Schema{
            type: :object,
            properties: %{
              date: %Schema{type: :string, description: "Date in string format"},
              description: %Schema{
                type: :string,
                description: "Description of the date's significance"
              }
            }
          }
        },
        important_clauses: %Schema{
          type: :array,
          description: "Extraction result - important clauses",
          items: %Schema{
            type: :object,
            properties: %{
              clause_title: %Schema{type: :string, description: "Title of the clause"},
              summary: %Schema{type: :string, description: "Summary of the clause"}
            }
          }
        },
        financial_details: %Schema{
          type: :object,
          description: "Extraction result - financial information",
          properties: %{
            contract_value: %Schema{
              type: :object,
              description: "Contract value information",
              properties: %{
                amount: %Schema{type: :string, description: "Contract amount"},
                currency: %Schema{type: :string, description: "Currency code"}
              }
            },
            expiry_date: %Schema{type: :string, description: "Contract expiry date"},
            payment_schedule: %Schema{
              type: :array,
              description: "Payment schedule details",
              items: %Schema{
                type: :object,
                properties: %{
                  amount: %Schema{type: :string, description: "Payment amount"},
                  currency: %Schema{type: :string, description: "Currency code"},
                  due_date: %Schema{type: :string, description: "Payment due date"},
                  remarks: %Schema{type: :string, description: "Additional remarks"}
                }
              }
            }
          }
        },
        suggestions: %Schema{
          type: :array,
          description: "Suggestions result - improvement recommendations",
          items: %Schema{
            type: :object,
            properties: %{
              title: %Schema{type: :string, description: "Suggestion title"},
              description: %Schema{
                type: :string,
                description: "Detailed description of the suggestion"
              },
              priority: %Schema{
                type: :string,
                enum: ["high", "medium", "low"],
                description: "Priority level"
              },
              text_to_replace: %Schema{
                type: :string,
                description: "Original text that should be replaced"
              },
              text_replacement: %Schema{type: :string, description: "Suggested replacement text"},
              reason: %Schema{type: :string, description: "Reason for the suggestion"}
            }
          }
        },
        refined_content: %Schema{
          type: :string,
          description: "Refinement result - the refined/improved content"
        }
      },
      example: %{
        entities: %{
          people: ["John Doe", "Jane Smith"],
          companies: ["Acme Corp", "Tech Solutions Inc"],
          government_bodies: ["Department of Commerce"],
          courts: ["Supreme Court"]
        },
        dates: [
          %{date: "2024-01-15", description: "Contract start date"},
          %{date: "2024-12-31", description: "Contract expiry date"}
        ],
        important_clauses: [
          %{
            clause_title: "Termination Clause",
            summary: "Contract can be terminated with 30 days notice"
          }
        ],
        financial_details: %{
          contract_value: %{amount: "100000", currency: "USD"},
          expiry_date: "2024-12-31",
          payment_schedule: [
            %{
              amount: "50000",
              currency: "USD",
              due_date: "2024-06-30",
              remarks: "First installment"
            }
          ]
        }
      }
    })
  end
end
