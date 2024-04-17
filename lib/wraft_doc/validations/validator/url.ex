defmodule WraftDoc.Validations.Validator.Url do
  @moduledoc """
  The Url validator module.
  Validates that the given url follows the correct format
  """
  use WraftDoc.Validations.Validator
  @behaviour WraftDoc.Validations.Validator.Behaviour

  @doc """
  Validates the user input based on correct url format.
  """
  @spec run(map, any()) :: boolean
  def run(_, user_input) do
    case URI.parse(user_input) do
      %URI{scheme: nil} -> false
      %URI{host: nil} -> false
      _ -> true
    end
  end
end
