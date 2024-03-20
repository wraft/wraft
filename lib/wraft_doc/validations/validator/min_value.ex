defmodule WraftDoc.Validations.Validator.MinValue do
  @moduledoc """
  The MinValue validator module.
  Validates that the user input is greater than or equal to the minimum value.
  """

  use WraftDoc.Validations.Validator
  @behaviour WraftDoc.Validations.Validator.Behaviour

  @doc """
  Validates the user input based on the given minimum value.
  """
  def run(%{"value" => standard_value}, user_input) when is_integer(user_input),
    do: user_input >= standard_value
end
