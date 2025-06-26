defmodule WraftDoc.AiAgents.Tools.DocExtraction do
  @moduledoc """
  Tool for converting markdown document text into structured data based on a prompt.
  """
  use WraftDoc.AiAgents.Tool,
    name: "doc_extraction",
    description: "Converts markdown document text into structured data based on a prompt",
    response_model: WraftDoc.AiAgents.ResponseModel.Extraction
end
