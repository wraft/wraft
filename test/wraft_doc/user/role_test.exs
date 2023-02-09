defmodule WraftDoc.Account.RoleTest do
  use WraftDoc.ModelCase
  @moduletag :account

  alias WraftDoc.Account.Role
  alias WraftDoc.Factory

  @valid_attrs %{name: "user"}
  @invalid_attrs %{}

  test "changeset with valid attributes" do
    organisation = Factory.insert(:organisation)
    attrs = Map.put(@valid_attrs, :organisation_id, organisation.id)
    changeset = Role.changeset(%Role{}, attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = Role.changeset(%Role{}, @invalid_attrs)
    refute changeset.valid?
  end

  # TODO - Test unique constraint

  # TODO - Test update_changeset
end
