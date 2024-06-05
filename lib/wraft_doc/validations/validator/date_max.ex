defmodule WraftDoc.Validations.Validator.DateMax do
  @moduledoc """
  The Required validator module.
  It validates the date max.
  """
  use WraftDoc.Validations.Validator
  @behaviour WraftDoc.Validations.Validator.Behaviour

  @doc """
  Validates the date max.
  """
  # TODO need to implement
  @spec run(map, any()) :: boolean
  def run(%{"value" => _value}, _user_input), do: true
end
