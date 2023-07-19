defmodule WraftDoc.Account.UserOrganisationTest do
  use WraftDoc.ModelCase
  @moduletag :account
  alias WraftDoc.Account.UserOrganisation
  import WraftDoc.Factory

  describe "changeset/2" do
    test "creates valid changeset with valid params" do
      user = insert(:user)
      organisation = insert(:organisation)

      params = %{
        user_id: user.id,
        organisation_id: organisation.id
      }

      changeset = UserOrganisation.changeset(%UserOrganisation{}, params)
      assert changeset.valid?
    end

    test "creates invalid changeset with invalid params" do
      changeset = UserOrganisation.changeset(%UserOrganisation{}, %{})
      refute changeset.valid?
    end

    test "checks unique constraint on users_organisations" do
      user = insert(:user)
      organisation = insert(:organisation)

      params = %{
        user_id: user.id,
        organisation_id: organisation.id
      }

      {:ok, _} = %UserOrganisation{} |> UserOrganisation.changeset(params) |> Repo.insert()

      {:error, changeset} =
        %UserOrganisation{} |> UserOrganisation.changeset(params) |> Repo.insert()

      assert "already exist" in errors_on(
               changeset,
               :user_id
             )
    end

    test "checks foreign key constraint on invalid user" do
      organisation = insert(:organisation)

      params = %{
        user_id: Ecto.UUID.generate(),
        organisation_id: organisation.id
      }

      {:error, changeset} =
        %UserOrganisation{} |> UserOrganisation.changeset(params) |> Repo.insert()

      assert "Please enter an existing user" in errors_on(changeset, :user_id)
    end

    test "checks foreign key constraint on invalid organisation" do
      user = insert(:user)

      params = %{
        user_id: user.id,
        organisation_id: Ecto.UUID.generate()
      }

      {:error, changeset} =
        %UserOrganisation{} |> UserOrganisation.changeset(params) |> Repo.insert()

      assert "Please enter a valid organisation" in errors_on(changeset, :organisation_id)
    end

    test "returns error changeset when all the required fields are missing" do
      changeset = UserOrganisation.changeset(%UserOrganisation{}, %{})

      assert "can't be blank" in errors_on(changeset, :user_id)
      assert "can't be blank" in errors_on(changeset, :organisation_id)
    end
  end

  describe "delete_changeset/2" do
    test "returns valid changeset with valid attrs" do
      changeset =
        UserOrganisation.delete_changeset(%UserOrganisation{}, %{
          deleted_at: NaiveDateTime.utc_now()
        })

      assert changeset.valid?
    end

    test "returns invalid changeset with invalid attrs" do
      changeset = UserOrganisation.delete_changeset(%UserOrganisation{}, %{})

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset, :deleted_at)
    end
  end
end
