defmodule WraftDocWeb.Api.V1.AIToolController do
  use WraftDocWeb, :controller
  use PhoenixSwagger

  plug(WraftDocWeb.Plug.AddActionLog)

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.AiAgents

  def swagger_definitions do
    %{
      AiToolRequest:
        swagger_schema do
          title("AI Tool Request")

          description(
            "Request body for AI tool execution. Either provide prompt_id for a saved prompt, or provide both prompt and prompt_type for inline execution."
          )

          type(:object)
          required([:content])

          properties do
            model_id(
              :string,
              "Model ID (optional - will use organization's default model if not provided)"
            )

            prompt_id(
              :string,
              "Database prompt ID (required if prompt and prompt_type are not provided)"
            )

            prompt(:string, "Inline prompt text (required if prompt_id is not provided)")

            prompt_type(
              :string,
              "Type of prompt when using inline prompt. Must be one of: suggestion, refinement, extraction",
              enum: ["suggestion", "refinement", "extraction"]
            )

            content(:string, "Content to process", required: true)
          end

          example(%{
            model_id: "123e4567-e89b-12d3-a456-426614174000",
            prompt: "Extract key information from this document",
            prompt_type: "extraction",
            content: "This is the document content to be processed..."
          })
        end,
      AiToolResult:
        swagger_schema do
          title("AI Tool Result")

          description(
            "Result from AI tool execution. The response structure depends on the agent type: extraction returns entities/dates/financial details, suggestions returns improvement recommendations, and refinement returns refined content."
          )

          type(:object)

          properties do
            entities(:object, "Extraction result - extracted entities",
              properties: %{
                people: %{
                  type: :array,
                  items: %{type: :string},
                  description: "Names of people mentioned"
                },
                companies: %{
                  type: :array,
                  items: %{type: :string},
                  description: "Company names mentioned"
                },
                government_bodies: %{
                  type: :array,
                  items: %{type: :string},
                  description: "Government organizations mentioned"
                },
                courts: %{type: :array, items: %{type: :string}, description: "Courts mentioned"}
              }
            )

            dates(:array, "Extraction result - important dates",
              items: %{
                type: :object,
                properties: %{
                  date: %{type: :string, description: "Date in string format"},
                  description: %{
                    type: :string,
                    description: "Description of the date's significance"
                  }
                }
              }
            )

            important_clauses(:array, "Extraction result - important clauses",
              items: %{
                type: :object,
                properties: %{
                  clause_title: %{type: :string, description: "Title of the clause"},
                  summary: %{type: :string, description: "Summary of the clause"}
                }
              }
            )

            financial_details(:object, "Extraction result - financial information",
              properties: %{
                contract_value: %{
                  type: :object,
                  description: "Contract value information",
                  properties: %{
                    amount: %{type: :string, description: "Contract amount"},
                    currency: %{type: :string, description: "Currency code"}
                  }
                },
                expiry_date: %{type: :string, description: "Contract expiry date"},
                payment_schedule: %{
                  type: :array,
                  description: "Payment schedule details",
                  items: %{
                    type: :object,
                    properties: %{
                      amount: %{type: :string, description: "Payment amount"},
                      currency: %{type: :string, description: "Currency code"},
                      due_date: %{type: :string, description: "Payment due date"},
                      remarks: %{type: :string, description: "Additional remarks"}
                    }
                  }
                }
              }
            )

            suggestions(:array, "Suggestions result - improvement recommendations",
              items: %{
                type: :object,
                properties: %{
                  title: %{type: :string, description: "Suggestion title"},
                  description: %{
                    type: :string,
                    description: "Detailed description of the suggestion"
                  },
                  priority: %{
                    type: :string,
                    enum: ["high", "medium", "low"],
                    description: "Priority level"
                  },
                  text_to_replace: %{
                    type: :string,
                    description: "Original text that should be replaced"
                  },
                  text_replacement: %{type: :string, description: "Suggested replacement text"},
                  reason: %{type: :string, description: "Reason for the suggestion"}
                }
              }
            )

            refined_content(:string, "Refinement result - the refined/improved content")
          end

          example(%{
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
          })
        end
    }
  end

  @doc """
  Execute AI tool with given model, prompt and content.
  Supports both database-stored prompts (via prompt_id) and inline prompts (via prompt + prompt_type).
  Model ID is optional - will use the organization's default model if not provided.
  """
  swagger_path :execute do
    post("/ai/generate")
    summary("Execute AI tool")

    description(
      "Execute AI tool with specified content. Either provide prompt_id for a saved prompt, or provide both prompt and prompt_type for inline execution. Model ID is optional and defaults to organization's default model."
    )

    operation_id("execute_ai_tool")
    consumes("application/json")

    parameters do
      body(:body, Schema.ref(:AiToolRequest), "AI tool execution request", required: true)
    end

    response(200, "Ok", Schema.ref(:AiToolResult))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not Found", Schema.ref(:Error))
    response(500, "Internal Server Error", Schema.ref(:Error))
  end

  @spec execute(Plug.Conn.t(), map) :: Plug.Conn.t()
  def execute(conn, params) do
    current_user = conn.assigns.current_user

    with {:ok, validated_params} <- AiAgents.validate_params(params),
         {:ok, model} <-
           AiAgents.get_model_or_default(validated_params, current_user.current_org_id),
         {:ok, prompt_data} <- AiAgents.get_prompt_data(validated_params),
         {:ok, result} <-
           AiAgents.execute(current_user, model, prompt_data, validated_params.content) do
      render(conn, "ai_tool_result.json", result: result)
    end
  end
end
