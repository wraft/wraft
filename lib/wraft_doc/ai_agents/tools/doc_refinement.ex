defmodule WraftDoc.AiAgents.Tools.DocRefinement do
  @moduledoc """
  Tool for enhancing a markdown document text based on a prompt.
  """
  use WraftDoc.AiAgents.Tool,
    name: "doc_refinement",
    description: "Enhances a markdown document text based on a prompt",
    response_model: WraftDoc.AiAgents.ResponseModel.Refinement
end
