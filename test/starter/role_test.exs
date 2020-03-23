defmodule WraftDoc.RoleTest do
  use WraftDoc.ModelCase
  alias WraftDoc.Account.Role

  @valid_attrs %{name: "user"}
  @invalid_attrs %{}

  test "changeset with valid attributes" do
    changeset = Role.changeset(%Role{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = Role.changeset(%Role{}, @invalid_attrs)
    refute changeset.valid?
  end
end
