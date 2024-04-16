defmodule WraftDoc.Validations.Validator.MinLengthTest do
  use WraftDoc.DataCase

  alias WraftDoc.Validations.Validator.MinLength

  describe "validate/2" do
    test "should return :ok when the length of the user input is greater than or equal to the minimum length" do
      assert MinLength.validate(%{validation: %{"value" => 10}}, "1234567890") == :ok
      assert MinLength.validate(%{validation: %{"value" => 10}}, "12345678901") == :ok
    end

    test "should return an error tuple when the length of the user input is less than the minimum length" do
      assert MinLength.validate(
               %{
                 validation: %{"value" => 10},
                 error_message: "must be greater than or equal to 10"
               },
               "123456789"
             ) == {:error, "must be greater than or equal to 10"}
    end

    test "should return an error tuple when the user input in invalid" do
      assert MinLength.validate(
               %{
                 validation: %{"value" => 10},
                 error_message: "must be greater than or equal to 10"
               },
               %{a: "invalid"}
             ) == {:error, "must be greater than or equal to 10"}
    end
  end

  describe "run/2" do
    test "should return true when the length of the user input is greater than or equal to the minimum length" do
      assert MinLength.run(%{"value" => 10}, "1234567890") == true
      assert MinLength.run(%{"value" => 10}, "12345678901") == true
    end

    test "should return false when the length of the user input is less than the minimum length" do
      assert MinLength.run(%{"value" => 10}, "123456789") == false
    end
  end
end
