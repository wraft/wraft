defmodule WraftDoc.Validations.Validator.Regex do
  @moduledoc """
  The Required validator module.
  It validates the regex.
  """
  use WraftDoc.Validations.Validator
  @behaviour WraftDoc.Validations.Validator.Behaviour

  @doc """
  Validates the regex.
  """
  # TODO
  @spec run(map, any()) :: boolean
  def run(%{"value" => _value}, _user_input), do: true
end
