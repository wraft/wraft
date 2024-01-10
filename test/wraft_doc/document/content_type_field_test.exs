defmodule WraftDocTest.Document.ContentTypeFieldTest do
  @moduledoc false
  use WraftDoc.ModelCase
  @moduletag :document
  alias WraftDoc.Document.ContentTypeField
  import WraftDoc.Factory

  @invalid_attrs %{content_type_id: nil, field_id: nil}

  describe "changeset/2" do
    test "changeset with valid attributes" do
      content_type = insert(:content_type)
      field = insert(:field)

      changeset =
        ContentTypeField.changeset(%ContentTypeField{}, %{
          content_type_id: content_type.id,
          field_id: field.id
        })

      assert changeset.valid?
    end

    test "changeset with invalid attributes" do
      changeset = ContentTypeField.changeset(%ContentTypeField{}, @invalid_attrs)
      refute changeset.valid?
    end

    test "foreign key constraint on content_type_id" do
      field = insert(:field)

      params = %{
        content_type_id: Ecto.UUID.generate(),
        field_id: field.id
      }

      {:error, changeset} =
        %ContentTypeField{} |> ContentTypeField.changeset(params) |> Repo.insert()

      assert "Please enter an existing content type" in errors_on(changeset, :content_type_id)
    end

    test "foreign key constraint on field_id" do
      content_type = insert(:content_type)

      params = %{
        content_type_id: content_type.id,
        field_id: Ecto.UUID.generate()
      }

      {:error, changeset} =
        %ContentTypeField{} |> ContentTypeField.changeset(params) |> Repo.insert()

      assert "Please enter a valid field" in errors_on(changeset, :field_id)
    end

    test "content type field unique constraint" do
      content_type = insert(:content_type)
      field = insert(:field)

      params = %{
        content_type_id: content_type.id,
        field_id: field.id
      }

      {:ok, _} = %ContentTypeField{} |> ContentTypeField.changeset(params) |> Repo.insert()

      {:error, changeset} =
        %ContentTypeField{} |> ContentTypeField.changeset(params) |> Repo.insert()

      assert "already exist" in errors_on(
               changeset,
               :content_type_id
             )
    end
  end
end
