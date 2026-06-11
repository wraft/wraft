defmodule WraftDoc.AiAgents.ResponseModel.Suggestions do
  @moduledoc """
  Schema for suggesting improvements to extracted information.
  """

  use Ecto.Schema

  embedded_schema do
    embeds_many :suggestions, Suggestion do
      field(:title, :string)
      field(:description, :string)
      field(:priority, Ecto.Enum, values: [:high, :medium, :low])
      field(:text_to_replace, :string)
      field(:text_replacement, :string)
      field(:reason, :string)
    end
  end

  @doc """
  JSON Schema describing the expected LLM output for this model.
  """
  @spec llm_schema() :: map()
  def llm_schema do
    string = %{"type" => "string"}

    %{
      "type" => "object",
      "additionalProperties" => false,
      "required" => ["suggestions"],
      "properties" => %{
        "suggestions" => %{
          "type" => "array",
          "items" => %{
            "type" => "object",
            "additionalProperties" => false,
            "required" => [
              "title",
              "description",
              "priority",
              "text_to_replace",
              "text_replacement",
              "reason"
            ],
            "properties" => %{
              "title" => string,
              "description" => string,
              "priority" => %{"type" => "string", "enum" => ["high", "medium", "low"]},
              "text_to_replace" => string,
              "text_replacement" => string,
              "reason" => string
            }
          }
        }
      }
    }
  end
end
