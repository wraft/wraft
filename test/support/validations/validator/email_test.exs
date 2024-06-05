defmodule WraftDoc.Validations.Validator.EmailTest do
  use WraftDoc.DataCase

  alias WraftDoc.Validations.Validator.Email

  describe "validate/2" do
    test "should return :ok when the user input is a valid email address" do
      assert Email.validate(%{validation: %{"rule" => "email"}}, "example@gmail.com") == :ok
    end

    test "should return an error tuple when the user input is an invalid email address" do
      assert Email.validate(
               %{validation: %{"rule" => "email"}, error_message: "invalid email"},
               "invalid_email"
             ) == {:error, "invalid email"}
    end
  end

  describe "run/2" do
    test "should return true when the user input is a valid email address" do
      assert Email.run(%{"rule" => "email"}, "example@gmail.com") == true
    end

    test "should return false when the user input is an invalid email address" do
      assert Email.run(%{"rule" => "email"}, "invalid_email") == false
    end
  end
end
