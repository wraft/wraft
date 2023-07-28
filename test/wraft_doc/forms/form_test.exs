defmodule WraftDoc.Forms.FormTest do
  @moduledoc false
  use WraftDoc.ModelCase
  @moduletag :forms
  alias WraftDoc.Forms.Form
  import WraftDoc.Factory

  @invalid_attrs %{creator_id: nil, organisation_id: nil}

  describe "changeset/2" do
    test "changeset with valid attributes" do
      organisation = insert(:organisation)
      user = insert(:user)

      changeset =
        Form.changeset(%Form{}, %{
          description: "This is a sample description",
          name: "Name of the form",
          prefix: "This is the prefix",
          status: :inactive,
          organisation_id: organisation.id,
          creator_id: user.id
        })

      assert changeset.valid?
    end

    test "changeset with invalid attributes" do
      changeset = Form.changeset(%Form{}, @invalid_attrs)
      refute changeset.valid?
    end

    test "foreign key constraint on user_id" do
      organisation = insert(:organisation)

      params = %{
        description: "This is a sample description",
        name: "Name of the form",
        prefix: "This is the prefix",
        status: :inactive,
        organisation_id: organisation.id,
        creator_id: Ecto.UUID.generate()
      }

      {:error, changeset} = %Form{} |> Form.changeset(params) |> Repo.insert()

      assert "Please enter a valid user" in errors_on(changeset, :creator_id)
    end

    test "foreign key constraint on organisation_id" do
      user = insert(:user)

      params = %{
        description: "This is a sample description",
        name: "Name of the form",
        prefix: "This is the prefix",
        status: :inactive,
        organisation_id: Ecto.UUID.generate(),
        creator_id: user.id
      }

      {:error, changeset} = %Form{} |> Form.changeset(params) |> Repo.insert()

      assert "Please enter a valid organisation" in errors_on(changeset, :organisation_id)
    end
  end
end
