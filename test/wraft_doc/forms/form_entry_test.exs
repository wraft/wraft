defmodule WraftDoc.Forms.FormEntryTest do
  @moduledoc false
  use WraftDoc.ModelCase
  @moduletag :forms
  alias WraftDoc.Forms.FormEntry
  import WraftDoc.Factory

  @invalid_attrs %{data: %{}, status: nil, user_id: nil, form_id: nil}

  @data %{
    1 => %{field_id: 1, value: "random@gmail.com"},
    2 => %{field_id: 12, value: "random string"}
  }

  describe "changeset/2" do
    test "changeset with valid attributes" do
      form = insert(:form)
      user = insert(:user)

      changeset =
        FormEntry.changeset(%FormEntry{}, %{
          data: @data,
          status: :submitted,
          user_id: user.id,
          form_id: form.id
        })

      assert changeset.valid?
    end

    test "changeset with invalid attributes" do
      changeset = FormEntry.changeset(%FormEntry{}, @invalid_attrs)
      refute changeset.valid?
    end

    test "foreign key constraint on form_id" do
      form_entry = insert(:form_entry)

      params = %{
        data: @data,
        status: :submitted,
        form_id: Ecto.UUID.generate(),
        user_id: form_entry.user_id
      }

      {:error, changeset} = %FormEntry{} |> FormEntry.changeset(params) |> Repo.insert()

      assert "Please enter an existing form" in errors_on(changeset, :form_id)
    end

    test "foreign key constraint on user_id" do
      form_entry = insert(:form_entry)

      params = %{
        data: @data,
        status: :submitted,
        form_id: form_entry.form_id,
        user_id: Ecto.UUID.generate()
      }

      {:error, changeset} = %FormEntry{} |> FormEntry.changeset(params) |> Repo.insert()

      assert "Please enter an existing user" in errors_on(changeset, :user_id)
    end
  end
end
