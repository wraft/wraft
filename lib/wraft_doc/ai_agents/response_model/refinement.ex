defmodule WraftDoc.AiAgents.ResponseModel.Refinement do
  @moduledoc """
  Schema for refining extracted information.
  """

  use Ecto.Schema

  embedded_schema do
    field(:refined_content, :string)
  end

  @doc """
  JSON Schema describing the expected LLM output for this model.
  """
  @spec llm_schema() :: map()
  def llm_schema do
    %{
      "type" => "object",
      "additionalProperties" => false,
      "required" => ["refined_content"],
      "properties" => %{"refined_content" => %{"type" => "string"}}
    }
  end
end
