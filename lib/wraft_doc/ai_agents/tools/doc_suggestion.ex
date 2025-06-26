defmodule WraftDoc.AiAgents.Tools.DocSuggestion do
  @moduledoc """
  Tool for generating document suggestions based on a prompt and markdown content.
  """
  use WraftDoc.AiAgents.Tool,
    name: "doc_suggestion",
    description: "Converts markdown document text into structured data based on a prompt",
    response_model: WraftDoc.AiAgents.ResponseModel.Suggestions
end
