defmodule WraftDoc.Validations.Validator.MinValueTest do
  use WraftDoc.DataCase

  alias WraftDoc.Validations.Validator.MinValue

  describe "validate/2" do
    test "should return :ok when the user input is greater than or equal to the minimum value" do
      assert MinValue.validate(%{validation: %{"value" => 10}}, 15) == :ok
    end

    test "should return an error tuple when the user input is less than the minimum value" do
      assert MinValue.validate(
               %{
                 validation: %{"value" => 10},
                 error_message: "must be greater than or equal to 10"
               },
               5
             ) == {:error, "must be greater than or equal to 10"}
    end

    test "should return an error tuple when the user input in invalid" do
      assert MinValue.validate(
               %{
                 validation: %{"value" => 10},
                 error_message: "must be greater than or equal to 10"
               },
               "invalid"
             ) == {:error, "must be greater than or equal to 10"}
    end
  end

  describe "run/2" do
    test "should return true when the user input is greater than or equal to the minimum value" do
      assert MinValue.run(%{"value" => 10}, 15) == true
      assert MinValue.run(%{"value" => 10}, 10) == true
    end

    test "should return false when the user input is less than the minimum value" do
      assert MinValue.run(%{"value" => 10}, 5) == false
    end
  end
end
