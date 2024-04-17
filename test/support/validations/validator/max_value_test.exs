defmodule WraftDoc.Validations.Validator.MaxValueTest do
  use WraftDoc.DataCase

  alias WraftDoc.Validations.Validator.MaxValue

  describe "validate/2" do
    test "should return :ok when the user input is less than or equal to the maximum value" do
      assert MaxValue.validate(%{validation: %{"value" => 10}}, 5) == :ok
    end

    test "should return an error tuple when the user input is greater than the maximum value" do
      assert MaxValue.validate(
               %{validation: %{"value" => 10}, error_message: "must be less than or equal to 10"},
               15
             ) == {:error, "must be less than or equal to 10"}
    end

    test "should return and error tuple when the user input is invalid" do
      assert MaxValue.validate(
               %{validation: %{"value" => 10}, error_message: "must be less than or equal to 10"},
               "invalid"
             ) == {:error, "must be less than or equal to 10"}
    end
  end

  describe "run/2" do
    test "should return true when the user input is less than or equal to the maximum value" do
      assert MaxValue.run(%{"value" => 10}, 5) == true
      assert MaxValue.run(%{"value" => 10}, 10) == true
    end

    test "should return false when the user input is greater than the maximum value" do
      assert MaxValue.run(%{"value" => 10}, 15) == false
    end
  end
end
