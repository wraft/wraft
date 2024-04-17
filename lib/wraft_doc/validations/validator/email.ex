defmodule WraftDoc.Validations.Validator.Email do
  @moduledoc """
  The Email validator module.
  Validates that the given email follows the correct format
  """

  use WraftDoc.Validations.Validator
  @behaviour WraftDoc.Validations.Validator.Behaviour

  @doc """
  Validates the user input based on correct email format.
  """
  @spec run(map, any()) :: boolean
  def run(_, user_input), do: String.match?(user_input, ~r/@/)
end
