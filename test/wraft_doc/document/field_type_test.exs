defmodule WraftDoc.Document.FieldTypeTest do
  @moduledoc false
  use WraftDoc.ModelCase
  alias WraftDoc.Document.FieldType
  @moduletag :document

  @valid_attrs %{
    name: "Date",
    description: "A data field",
    meta: %{allowed_validations: [:required, :min_value, :max_value]},
    validation: [
      %{
        "validation" => %{rule: :required, value: false},
        "error_message" => "Some error message"
      }
    ]
  }

  @invalid_attrs %{name: ""}

  test "changeset with valid attributes" do
    changeset = FieldType.changeset(%FieldType{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = FieldType.changeset(%FieldType{}, @invalid_attrs)
    refute changeset.valid?
  end

  test "field type name unique constraint" do
    {:ok, _field_type} = %FieldType{} |> FieldType.changeset(@valid_attrs) |> Repo.insert()
    {:error, changeset} = %FieldType{} |> FieldType.changeset(@valid_attrs) |> Repo.insert()

    assert "Field type with the same name exists. Use another name.!" in errors_on(
             changeset,
             :name
           )
  end
end
