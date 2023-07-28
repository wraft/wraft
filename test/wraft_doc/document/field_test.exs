defmodule WraftDoc.Document.FieldTest do
  @moduledoc false
  use WraftDoc.ModelCase
  import Ecto
  import WraftDoc.Factory
  alias WraftDoc.Document.Field
  @moduletag :document

  @valid_attrs %{name: "employee"}

  @invalid_attrs %{name: ""}

  test "changeset with valid attrs" do
    changeset = Field.changeset(%Field{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = Field.changeset(%Field{}, @invalid_attrs)
    refute changeset.valid?
  end

  # TODO need to update the constraint as the table name is changed to field
  test "content type field name unique constraint" do
    changeset =
      insert(:content_type)
      |> build_assoc(:content_type_fields, field_type: insert(:field_type))
      |> Field.changeset(@valid_attrs)

    {:ok, _c_type_field} = Repo.insert(changeset)
    {:error, changeset} = Repo.insert(changeset)
    assert "Field type already added.!" in errors_on(changeset, :name)
  end
end
