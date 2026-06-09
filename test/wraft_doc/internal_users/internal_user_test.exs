defmodule WraftDocs.InternalUsers.InternalUserTest do
  use WraftDoc.ModelCase

  alias WraftDoc.InternalUsers.InternalUser
  import WraftDoc.Factory

  @valid_params %{
    email: "user@wraft.com",
    password: "a-long-enough-password"
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
      attrs = Map.put(@valid_params, :password, "short-pass")
      changeset = InternalUser.changeset(%InternalUser{}, attrs)

      refute changeset.valid?
      assert "should be at least 12 character(s)" in errors_on(changeset, :password)
    end

    test "returns an invalid changeset with password above the bcrypt limit" do
      attrs = Map.put(@valid_params, :password, String.duplicate("q", 73))
      changeset = InternalUser.changeset(%InternalUser{}, attrs)

      refute changeset.valid?
      assert "should be at most 72 character(s)" in errors_on(changeset, :password)
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

    test "bumps session_epoch on deactivation" do
      internal_user = insert(:internal_user, session_epoch: 3)
      changeset = InternalUser.update_changeset(internal_user, %{"is_deactivated" => "true"})

      assert Ecto.Changeset.get_change(changeset, :session_epoch) == 4
    end

    test "bumps session_epoch on password change" do
      internal_user = insert(:internal_user)

      changeset =
        InternalUser.update_changeset(internal_user, %{
          "is_deactivated" => "false",
          "password" => "a-brand-new-password"
        })

      assert Ecto.Changeset.get_change(changeset, :session_epoch) == 1
    end

    test "does not bump session_epoch on a plain email update" do
      internal_user = insert(:internal_user)

      changeset =
        InternalUser.update_changeset(internal_user, %{
          "is_deactivated" => "false",
          "email" => "new-address@wraft.com"
        })

      assert Ecto.Changeset.get_change(changeset, :session_epoch) == nil
    end

    test "returns an invalid changeset with invalid params" do
      internal_user = insert(:internal_user)
      changeset = InternalUser.update_changeset(internal_user, %{"is_deactivated" => nil})

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset, :is_deactivated)
    end
  end
end
