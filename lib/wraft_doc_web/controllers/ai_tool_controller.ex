defmodule WraftDocWeb.Api.V1.AiToolController do
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
          description("Request body for AI tool execution")
          type(:object)
          required([:model_id, :prompt_id, :content])

          properties do
            model_id(:string, "Model ID", required: true)
            prompt_id(:string, "Prompt ID", required: true)
            content(:string, "Content to process", required: true)
          end
        end,
      AiToolResult:
        swagger_schema do
          title("AI Tool Result")

          description(
            "Result from AI tool execution. Can be extraction results (with entities, dates, financial_details), suggestions (with suggestions array), or refinement (with result string)"
          )

          type(:object)

          properties do
            extraction(:object, "Extraction result with entities, dates, and financial details",
              properties: %{
                entities: %{
                  type: :object,
                  description: "Extracted entities",
                  properties: %{
                    people: %{type: :array, items: %{type: :string}},
                    companies: %{type: :array, items: %{type: :string}},
                    government_bodies: %{type: :array, items: %{type: :string}},
                    courts: %{type: :array, items: %{type: :string}}
                  }
                },
                dates: %{
                  type: :array,
                  description: "Important dates",
                  items: %{
                    type: :object,
                    properties: %{
                      date: %{type: :string},
                      description: %{type: :string}
                    }
                  }
                },
                important_clauses: %{
                  type: :array,
                  description: "Important clauses",
                  items: %{
                    type: :object,
                    properties: %{
                      clause_title: %{type: :string},
                      summary: %{type: :string}
                    }
                  }
                },
                financial_details: %{
                  type: :object,
                  description: "Financial details",
                  properties: %{
                    contract_value: %{
                      type: :object,
                      properties: %{
                        amount: %{type: :number},
                        currency: %{type: :string}
                      }
                    },
                    expiry_date: %{type: :string},
                    payment_schedule: %{
                      type: :array,
                      items: %{
                        type: :object,
                        properties: %{
                          amount: %{type: :number},
                          currency: %{type: :string},
                          due_date: %{type: :string},
                          remarks: %{type: :string}
                        }
                      }
                    }
                  }
                }
              }
            )

            suggestions(:object, "Suggestions result with improvement recommendations",
              properties: %{
                suggestions: %{
                  type: :array,
                  description: "Array of suggestions for improvement",
                  items: %{
                    type: :object,
                    properties: %{
                      title: %{type: :string},
                      description: %{type: :string},
                      priority: %{type: :string, enum: ["high", "medium", "low"]},
                      text_to_replace: %{type: :string},
                      text_replacement: %{type: :string},
                      reason: %{type: :string}
                    }
                  }
                }
              }
            )

            refinement(:object, "Refinement result with refined content",
              properties: %{
                result: %{type: :string, description: "Refined content"}
              }
            )
          end
        end
    }
  end

  @doc """
  Execute AI tool with given model, prompt and content.
  """
  swagger_path :execute do
    post("/ai/generate")
    summary("Execute AI tool")
    description("Execute AI tool with specified model, prompt and content")
    operation_id("execute_ai_tool")
    consumes("application/json")

    parameters do
      body(:body, Schema.ref(:AiToolRequest), "AI tool execution request", required: true)
    end

    response(200, "Ok", Schema.ref(:AiToolResult))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(404, "Not Found", Schema.ref(:Error))
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
