defmodule WraftDoc.Validations.Validator.FileSize do
  @moduledoc """
  The Required validator module.
  It validates the file size.
  """
  use WraftDoc.Validations.Validator
  @behaviour WraftDoc.Validations.Validator.Behaviour

  @doc """
  Validates the file size.
  """
  # TODO
  @spec run(map, any()) :: boolean
  def run(%{"value" => _value}, _user_input), do: true
end
