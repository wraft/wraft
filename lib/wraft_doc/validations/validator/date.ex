defmodule WraftDoc.Validations.Validator.Date do
  @moduledoc """
  The Required validator module.
  It validates the date.
  """
  use WraftDoc.Validations.Validator
  @behaviour WraftDoc.Validations.Validator.Behaviour

  @doc """
  Validates the date.
  """
  # TODO
  @spec run(map, any()) :: boolean
  def run(%{"value" => _value}, _user_input), do: true
end
