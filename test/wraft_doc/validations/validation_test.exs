defmodule WraftDoc.Validations.ValidationTest do
  @moduledoc false
  use WraftDoc.ModelCase
  @moduletag :forms
  alias WraftDoc.Validations.Validation

  @valid_attrs %{
    validation: %{rule: :required, value: true},
    error_message: "Some error message"
  }

  @invalid_attrs %{}

  describe "changeset/2" do
    test "changeset with valid attributes" do
      changeset = Validation.changeset(%Validation{}, @valid_attrs)
      assert changeset.valid?
    end

    test "changeset with missing attributes" do
      changeset = Validation.changeset(%Validation{}, @invalid_attrs)
      refute changeset.valid?
    end
  end
end
