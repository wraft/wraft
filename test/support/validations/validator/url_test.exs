defmodule WraftDoc.Validations.Validator.UrlTest do
  use WraftDoc.DataCase

  alias WraftDoc.Validations.Validator.Url

  describe "validate/2" do
    test "should return :ok when the user input is a valid url" do
      assert Url.validate(
               %{validation: %{"rule" => "url"}, error_message: "invalid url"},
               "https://www.google.com/"
             ) == :ok
    end

    test "should return an error tuple when the user input is an invalid url" do
      assert Url.validate(
               %{validation: %{"rule" => "url"}, error_message: "invalid url"},
               "invalid_url"
             ) == {:error, "invalid url"}
    end
  end

  describe "run/2" do
    test "should return true when the user input is a valid url" do
      assert Url.run(%{"rule" => "url"}, "https://www.google.com/") == true
    end

    test "should return false when the user input is a valid url" do
      assert Url.run(%{"rule" => "url"}, "invalid url") == false
    end
  end
end
