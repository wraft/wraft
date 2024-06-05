defmodule WraftDoc.Validations.Validator.DateMin do
  @moduledoc """
  The Required validator module.
  It validates the date min.
  """
  use WraftDoc.Validations.Validator
  @behaviour WraftDoc.Validations.Validator.Behaviour

  @doc """
  Validates the date min.
  """
  # TODO need to implement date min.
  @spec run(map, any()) :: boolean
  def run(%{"value" => _value}, _user_input), do: true
end
