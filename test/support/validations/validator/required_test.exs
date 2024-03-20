defmodule WraftDoc.Validations.Validator.RequiredTest do
  use WraftDoc.DataCase

  alias WraftDoc.Validations.Validator.Required

  describe "run/2" do
    test "should return true when the user input is NOT blank and validation is true" do
      assert Required.run(%{"value" => true}, "not blank") == true
    end

    test "should return false when the user input is blank and validation is true" do
      assert Required.run(%{"value" => true}, "") == false
    end

    test "should return true when the user input is NOT blank and validation is false" do
      assert Required.run(%{"value" => false}, "any value") == true
    end

    test "should return true when the user input is blank and validation is false" do
      assert Required.run(%{"value" => false}, "") == true
    end
  end
end
