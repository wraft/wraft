defmodule WraftDoc.Document.ContentTypeFieldTest do
  use WraftDoc.ModelCase
  import WraftDoc.Factory
  alias WraftDoc.Document.ContentTypeField
  import Ecto

  @valid_attrs %{name: "employee"}

  @invalid_attrs %{name: ""}

  test "changeset with valid attrs" do
    changeset = ContentTypeField.changeset(%ContentTypeField{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = ContentTypeField.changeset(%ContentTypeField{}, @invalid_attrs)
    refute changeset.valid?
  end

  test "content type field name unique constraint" do
    changeset =
      insert(:content_type)
      |> build_assoc(:fields, field_type: insert(:field_type))
      |> ContentTypeField.changeset(@valid_attrs)

    {:ok, _c_type_field} = Repo.insert(changeset)
    {:error, changeset} = Repo.insert(changeset)
    assert "Field type already added.!" in errors_on(changeset, :name)
  end
end
