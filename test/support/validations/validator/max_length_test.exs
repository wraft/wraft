defmodule WraftDoc.Validations.Validator.MaxLengthTest do
  use WraftDoc.DataCase

  alias WraftDoc.Validations.Validator.MaxLength

  describe "validate/2" do
    test "should return :ok when the length of the user input is less than or equal to the maximum length" do
      assert MaxLength.validate(%{validation: %{"value" => 10}}, "1234567890") == :ok
      assert MaxLength.validate(%{validation: %{"value" => 10}}, "12345") == :ok
    end

    test "should return an error tuple when the length of the user input is greater than the maximum length" do
      assert MaxLength.validate(
               %{validation: %{"value" => 10}, error_message: "must be less than or equal to 10"},
               "12345678901"
             ) == {:error, "must be less than or equal to 10"}
    end

    test "should return an error tuple when the user input in invalid" do
      assert MaxLength.validate(
               %{validation: %{"value" => 10}, error_message: "must be less than or equal to 10"},
               %{a: "invalid"}
             ) == {:error, "must be less than or equal to 10"}
    end
  end

  describe "run/2" do
    test "should return true when the length of the user input is less than or equal to the maximum length" do
      assert MaxLength.run(%{"value" => 10}, "1234567890") == true
      assert MaxLength.run(%{"value" => 10}, "12345") == true
    end

    test "should return false when the length of the user input is greater than the maximum length" do
      assert MaxLength.run(%{"value" => 10}, "12345678901") == false
    end
  end
end
