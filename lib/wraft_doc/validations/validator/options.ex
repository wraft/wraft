defmodule WraftDoc.Validations.Validator.Options do
  @moduledoc """
  The Required validator module.
  It validates the options.
  """
  use WraftDoc.Validations.Validator
  @behaviour WraftDoc.Validations.Validator.Behaviour

  @doc """
  Validates the options.
  """
  # TODO
  @spec run(map, any()) :: boolean
  def run(%{"value" => _value}, _user_input), do: true
end
