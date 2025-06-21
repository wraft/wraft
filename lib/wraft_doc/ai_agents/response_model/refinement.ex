defmodule WraftDoc.AiAgents.ResponseModel.Refinement do
  @moduledoc """
  Schema for refining extracted information.
  """

  use Ecto.Schema
  use Instructor

  embedded_schema do
    field(:refined_content, :string)
  end
end
