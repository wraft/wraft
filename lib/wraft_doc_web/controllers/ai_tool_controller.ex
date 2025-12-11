defmodule WraftDocWeb.Api.V1.AIToolController do
  use WraftDocWeb, :controller
  use OpenApiSpex.ControllerSpecs

  plug(WraftDocWeb.Plug.AddActionLog)

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.AiAgents

  alias WraftDocWeb.Schemas.AiTool
  alias WraftDocWeb.Schemas.Error

  tags(["AI"])

  operation(:execute,
    summary: "Execute AI tool",
    description:
      "Execute AI tool with specified content. Either provide prompt_id for a saved prompt, or provide both prompt and prompt_type for inline execution. Model ID is optional and defaults to organization's default model.",
    operation_id: "execute_ai_tool",
    request_body: {"AI tool execution request", "application/json", AiTool.AiToolRequest},
    responses: [
      ok: {"Ok", "application/json", AiTool.AiToolResult},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error},
      not_found: {"Not Found", "application/json", Error},
      internal_server_error: {"Internal Server Error", "application/json", Error}
    ]
  )

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
