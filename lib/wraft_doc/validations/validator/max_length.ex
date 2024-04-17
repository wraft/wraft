defmodule WraftDoc.Validations.Validator.MaxLength do
  @moduledoc """
    The MaxLength validator module.
    It validates that the length of the user input does not exceed the standard value.
  """
  use WraftDoc.Validations.Validator
  @behaviour WraftDoc.Validations.Validator.Behaviour

  def run(%{"value" => standard_value}, user_input),
    do: String.length(user_input) <= standard_value
end
