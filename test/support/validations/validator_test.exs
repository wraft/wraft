defmodule WraftDoc.Validations.ValidatorTest do
  use WraftDoc.DataCase

  defmodule TestValidator do
    use WraftDoc.Validations.Validator

    def run(%{"value" => standard}, input) when is_integer(input), do: standard > input
  end

  describe "validate/2" do
    test "should return :ok when the validation rule returns a success response" do
      assert TestValidator.validate(
               %{validation: %{"value" => 3}, error_message: "maximum value 3"},
               2
             ) == :ok
    end

    test "should return an error tuple when the validation rule does not return a success response" do
      assert TestValidator.validate(
               %{validation: %{"value" => 3}, error_message: "maximum value 3"},
               5
             ) == {:error, "maximum value 3"}
    end

    test "should return an error tuple when an exception is raised" do
      assert TestValidator.validate(
               %{validation: %{"value" => 3}, error_message: "minimum value 3"},
               "invalid"
             ) == {:error, "minimum value 3"}
    end
  end
end
