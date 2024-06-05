defmodule WraftDoc.Validations.Validator.Range do
  @moduledoc """
  The Required validator module.
  It validates the range.
  """
  use WraftDoc.Validations.Validator
  @behaviour WraftDoc.Validations.Validator.Behaviour

  @doc """
  Validates the range.
  """
  # TODO
  @spec run(map, any()) :: boolean
  def run(%{"value" => _value}, _user_input), do: true
end
