defmodule WraftDoc.Document.FieldTest do
  @moduledoc false
  use WraftDoc.ModelCase

  alias WraftDoc.Document.Field

  @valid_attrs %{name: "employee", organisation_id: Faker.UUID.v4()}
  @invalid_attrs %{name: ""}

  test "changeset with valid attrs" do
    changeset = Field.changeset(%Field{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = Field.changeset(%Field{}, @invalid_attrs)
    refute changeset.valid?
  end
end
