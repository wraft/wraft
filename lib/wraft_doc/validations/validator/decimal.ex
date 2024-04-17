defmodule WraftDoc.Validations.Validator.Decimal do
  @moduledoc """
  The Required validator module.
  It validates the decimal.
  """
  use WraftDoc.Validations.Validator
  @behaviour WraftDoc.Validations.Validator.Behaviour

  @doc """
  Validates the decimal.
  """
  # TODO
  @spec run(map, any()) :: boolean
  def run(%{"value" => _value}, _user_input), do: true
end
