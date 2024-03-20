defmodule WraftDoc.Validations.Validator do
  @moduledoc """
  The Validator module.

  This module is responsible for validating user input based on a set of predefined rules.
  It uses metaprogramming to define a `validate` function that can be used by other modules.
  The `validate` function takes a validation rule and user input as arguments.
  It then runs the appropriate validation rule on the user input and returns either :ok or an error message.

  It also provides the `@success_response` module attribute, which contains the success responses.
  All the possible success responses from the modules that use Validator should be included in this list.
  """

  defmacro __using__(_) do
    quote do
      @success_response [:ok, true]
      @doc """
      Validates the user input based on the given validation rule.

      ## Examples

          iex> WraftDoc.Validations.Validator.validate(%{"validation" => %{"rule" => "required", "value" => true}, "error_message" => "can't be blank"}, "input")
          :ok

          iex> WraftDoc.Validations.Validator.validate(%{"validation" => %{"rule" => "required", "value" => true}, "error_message" => "can't be blank"}, "")
          "can't be blank"

      """
      @spec validate(map, any) :: :ok | {:error, String.t()}

      def validate(validation, user_input) do
        case __MODULE__.run(validation.validation, user_input) do
          response when response in @success_response ->
            :ok

          _ ->
            {:error, validation.error_message}
        end
      rescue
        _ -> {:error, validation.error_message}
      end
    end
  end
end
