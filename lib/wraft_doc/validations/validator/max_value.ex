defmodule WraftDoc.Validations.Validator.MaxValue do
  @moduledoc """
  The MaxValue validator module.
  Validates that the user input is less than or equal to the maximum value.
  """

  use WraftDoc.Validations.Validator
  @behaviour WraftDoc.Validations.Validator.Behaviour

  @doc """
  Validates the user input based on the given maximum value.
  """
  @spec run(map, any()) :: boolean
  def run(%{"value" => standard_value}, user_input),
    do: user_input <= standard_value
end
