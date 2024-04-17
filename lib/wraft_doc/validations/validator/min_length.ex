defmodule WraftDoc.Validations.Validator.MinLength do
  @moduledoc """
  The MinLength validator module.
  It validates that the length of the user input is not less than the standard value.
  """
  use WraftDoc.Validations.Validator
  @behaviour WraftDoc.Validations.Validator.Behaviour

  @doc """
  Validates that the length of the user input is not less than the standard value.
  """
  @spec run(map, String.t()) :: boolean
  def run(%{"value" => standard_value}, user_input),
    do: String.length(user_input) >= standard_value
end
