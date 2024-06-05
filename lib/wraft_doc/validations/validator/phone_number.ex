defmodule WraftDoc.Validations.Validator.PhoneNumber do
  @moduledoc """
  The Required validator module.
  It validates the phone number.
  """
  use WraftDoc.Validations.Validator
  @behaviour WraftDoc.Validations.Validator.Behaviour

  @doc """
  Validates the phone number.
  """
  # TODO
  @spec run(map, any()) :: boolean
  def run(%{"value" => _value}, _user_input), do: true
end
