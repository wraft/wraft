defmodule WraftDoc.Validations.Validator.Required do
  @moduledoc """
  The Required validator module.
  It validates that the user input is not blank.
  """
  use WraftDoc.Validations.Validator
  @behaviour WraftDoc.Validations.Validator.Behaviour

  @doc """
  Validates that the user input is not blank.
  """
  @spec run(map, any()) :: boolean
  def run(%{"value" => true}, user_input), do: !is_nil(user_input) && user_input != ""
  def run(_, _), do: true
end
