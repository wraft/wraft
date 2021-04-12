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
    c_type = insert(:content_type)
    f_type = insert(:field_type)

    changeset =
      c_type
      |> build_assoc(:fields, field_type: f_type)
      |> ContentTypeField.changeset(@valid_attrs)

    {:ok, _c_type_field} = changeset |> Repo.insert()
    {:error, changeset} = changeset |> Repo.insert()
    assert "Field type already added.!" in errors_on(changeset, :name)
  end
end
