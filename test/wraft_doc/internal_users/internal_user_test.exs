defmodule WraftDocs.InternalUsers.InternalUserTest do
  use WraftDoc.ModelCase

  alias WraftDoc.InternalUsers
  alias WraftDoc.InternalUsers.InternalUser
  import WraftDoc.Factory

  @valid_params %{
    email: "user@wraft.com",
    password: "12345678"
  }

  describe "changeset/2" do
    test "returns a valid changeset with valid params" do
      changeset = InternalUser.changeset(%InternalUser{}, @valid_params)

      assert changeset.valid?
    end

    test "returns an invalid changeset with invalid params" do
      changeset = InternalUser.changeset(%InternalUser{}, %{})

      refute changeset.valid?
    end

    test "returns an invalid changeset with invalid email address" do
      attrs = Map.put(@valid_params, :email, "user")
      changeset = InternalUser.changeset(%InternalUser{}, attrs)

      refute changeset.valid?
      assert "has invalid format" in errors_on(changeset, :email)
    end

    test "returns an invalid changeset with short password" do
      attrs = Map.put(@valid_params, :password, "1234567")
      changeset = InternalUser.changeset(%InternalUser{}, attrs)

      refute changeset.valid?
      assert "should be at least 8 character(s)" in errors_on(changeset, :password)
    end

    test "returns an invalid changeset with long password" do
      attrs = Map.put(@valid_params, :password, String.duplicate("q", 23))
      changeset = InternalUser.changeset(%InternalUser{}, attrs)

      refute changeset.valid?
      assert "should be at most 22 character(s)" in errors_on(changeset, :password)
    end

    test "returns an invalid changeset with taken email" do
      Repo.insert!(%InternalUser{email: "user@wraft.com", encrypted_password: "123asd123asd"})

      {:error, changeset} =
        %InternalUser{}
        |> InternalUser.changeset(@valid_params)
        |> Repo.insert()

      refute changeset.valid?
      assert "Email already taken.! Try another email." in errors_on(changeset, :email)
    end

    test "generates an encrypted_password with valid params" do
      changeset = InternalUser.changeset(%InternalUser{}, @valid_params)

      assert changeset.valid?

      assert %{encrypted_password: password} = changeset.changes
      assert not is_nil(password)
    end
  end

  describe "update_changeset/2" do
    test "returns a valid changeset with valid params" do
      internal_user = insert(:internal_user)
      changeset = InternalUser.update_changeset(internal_user, %{"is_deactivated" => "true"})

      assert changeset.valid?
    end

    test "returns an invalid changeset with invalid params" do
      internal_user = insert(:internal_user)
      changeset = InternalUser.update_changeset(internal_user, %{"is_deactivated" => nil})

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset, :is_deactivated)
    end
  end
end
