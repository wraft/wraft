defmodule WraftDoc.ProfileTest do
  use WraftDoc.ModelCase
  alias WraftDoc.Account.Profile

  @valid_attrs %{
    name: "under world",
    gender: "male"
  }
  @invalid_attrs %{}

  test "changeset with valid attributes" do
    changeset = Profile.changeset(%Profile{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = Profile.changeset(%Profile{}, @invalid_attrs)
    refute changeset.valid?
  end
end
