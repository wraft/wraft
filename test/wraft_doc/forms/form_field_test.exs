defmodule WraftDoc.Form.FormFieldTest do
  @moduledoc false
  use WraftDoc.ModelCase
  @moduletag :forms
  alias WraftDoc.Forms.FormField
  import WraftDoc.Factory

  @invalid_attrs %{form_id: nil, field_id: nil}

  @validations [
    %{
      "validation" => %{"rule" => "required", "value" => false},
      "error_message" => "Some error message"
    },
    %{
      "validation" => %{"rule" => "min_length", "value" => 10},
      "error_message" => "Some error message 2"
    }
  ]

  @order 1

  describe "changeset/2" do
    test "changeset with valid attributes" do
      form = insert(:form)
      field = insert(:field)

      changeset =
        FormField.changeset(%FormField{}, %{
          order: @order,
          validations: @validations,
          form_id: form.id,
          field_id: field.id
        })

      assert changeset.valid?
    end

    test "changeset with invalid attributes" do
      changeset = FormField.changeset(%FormField{}, @invalid_attrs)
      refute changeset.valid?
    end

    test "foreign key constraint on form_id" do
      field = insert(:field)

      params = %{
        order: @order,
        validations: @validations,
        form_id: Ecto.UUID.generate(),
        field_id: field.id
      }

      {:error, changeset} = %FormField{} |> FormField.changeset(params) |> Repo.insert()

      assert "Please enter an existing form" in errors_on(changeset, :form_id)
    end

    test "foreign key constraint on field_id" do
      form = insert(:form)

      params = %{
        validations: @validations,
        order: @order,
        form_id: form.id,
        field_id: Ecto.UUID.generate()
      }

      {:error, changeset} = %FormField{} |> FormField.changeset(params) |> Repo.insert()

      assert "Please enter a valid field" in errors_on(changeset, :field_id)
    end

    test "form_field unique constraint" do
      form = insert(:form)
      field = insert(:field)

      params = %{
        order: @order,
        validations: @validations,
        form_id: form.id,
        field_id: field.id
      }

      {:ok, _} = %FormField{} |> FormField.changeset(params) |> Repo.insert()

      {:error, changeset} =
        %FormField{} |> FormField.changeset(%{params | order: @order + 1}) |> Repo.insert()

      assert "already exist" in errors_on(
               changeset,
               :form_id
             )
    end
  end
end
