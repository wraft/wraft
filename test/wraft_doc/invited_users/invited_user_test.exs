defmodule WraftDoc.InvitedUsers.InvitedUserTest do
  use WraftDoc.ModelCase
  import WraftDoc.Factory

  alias WraftDoc.InvitedUsers.InvitedUser
  alias WraftDoc.Repo

  @valid_attrs %{
    email: "test@xyz.com",
    status: "invited",
    organisation_id: Faker.UUID.v4()
  }

  @invalid_attrs %{}

  describe "changeset/2" do
    test "returns valid changeset with valid attrs" do
      changeset = InvitedUser.changeset(%InvitedUser{}, @valid_attrs)

      assert changeset.valid?
    end

    test "returns invalid changeset with invalid attrs" do
      changeset = InvitedUser.changeset(%InvitedUser{}, @invalid_attrs)

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset, :email)
      assert "can't be blank" in errors_on(changeset, :organisation_id)
    end

    test "returns invalid changeset with invalid email address" do
      params = Map.put(@valid_attrs, :email, "invalid_email")
      changeset = InvitedUser.changeset(%InvitedUser{}, params)

      refute changeset.valid?
      assert "has invalid format" in errors_on(changeset, :email)
    end

    test "returns invalid changeset with invalid status" do
      params = Map.put(@valid_attrs, :status, "invalid")
      changeset = InvitedUser.changeset(%InvitedUser{}, params)

      refute changeset.valid?
      assert "is invalid" in errors_on(changeset, :status)
    end

    test "returns invalid changeset with taken email-organisation combination" do
      %{email: email, organisation: %{id: organisation_id}} = insert(:invited_user)
      params = %{email: email, organisation_id: organisation_id}

      {:error, changeset} = %InvitedUser{} |> InvitedUser.changeset(params) |> Repo.insert()

      refute changeset.valid?
      assert "user already invited" in errors_on(changeset, :email)
    end
  end

  describe "status_changeset/2" do
    test "returns valid changeset with valid attrs" do
      changeset = InvitedUser.status_changeset(%InvitedUser{}, @valid_attrs)

      assert changeset.valid?
    end

    test "returns invalid changeset with invalid status" do
      changeset = InvitedUser.status_changeset(%InvitedUser{}, %{status: "invalid"})

      refute changeset.valid?
      assert "is invalid" in errors_on(changeset, :status)
    end
  end
end
