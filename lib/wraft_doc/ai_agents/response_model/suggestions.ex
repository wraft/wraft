defmodule WraftDoc.AiAgents.ResponseModel.Suggestions do
  @moduledoc """
  Schema for suggesting improvements to extracted information.
  """

  use Ecto.Schema
  use Instructor

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
end
