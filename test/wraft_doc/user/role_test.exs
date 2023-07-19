defmodule WraftDoc.Account.RoleTest do
  use WraftDoc.ModelCase
  @moduletag :account

  alias WraftDoc.Account.Role
  alias WraftDoc.Factory
  alias WraftDoc.Repo

  @valid_attrs %{name: "user", permissions: ["create:something"]}
  @invalid_attrs %{}

  describe "changeset/2" do
    test "returns valid changeset with valid attributes" do
      organisation = Factory.insert(:organisation)
      attrs = Map.put(@valid_attrs, :organisation_id, organisation.id)
      changeset = Role.changeset(%Role{}, attrs)
      assert changeset.valid?
    end

    test "returns invalid changeset with invalid attributes" do
      changeset = Role.changeset(%Role{}, @invalid_attrs)
      refute changeset.valid?

      assert "can't be blank" in errors_on(changeset, :name)
      assert "can't be blank" in errors_on(changeset, :organisation_id)
    end

    test "does not accept taken name-organisation_id combination" do
      role = Factory.insert(:role, name: "user")
      attrs = Map.put(@valid_attrs, :organisation_id, role.organisation_id)
      changeset = Role.changeset(%Role{}, attrs)

      assert {:error, changeset} = Repo.insert(changeset)
      assert "Role exist in this organisation" in errors_on(changeset, :name)
    end
  end

  describe "update_changeset/2" do
    test "returns valid changeset with valid attributes" do
      role = Factory.insert(:role)
      changeset = Role.update_changeset(role, @valid_attrs)
      assert changeset.valid?
      assert %{name: "user", permissions: ["create:something"]} == changeset.changes
    end

    test "returns invalid changeset with invalid attributes" do
      role = Factory.insert(:role)
      changeset = Role.update_changeset(role, %{name: nil})
      refute changeset.valid?

      assert "can't be blank" in errors_on(changeset, :name)
    end

    test "does not accept taken name-organisation_id combination" do
      organisation = Factory.insert(:organisation)
      Factory.insert(:role, name: "user", organisation: organisation)
      role = Factory.insert(:role, organisation: organisation)

      changeset = Role.update_changeset(role, @valid_attrs)

      assert {:error, changeset} = Repo.update(changeset)
      assert "Role exist in this organisation" in errors_on(changeset, :name)
    end
  end
end
