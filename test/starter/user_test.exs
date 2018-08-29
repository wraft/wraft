defmodule Starter.UserTest do
  use Starter.ModelCase

  alias Starter.User_management
  alias Starter.User_management.User

  @valid_attrs %{
    name: "User",
    email: "user@mail.com",
    password: "123456789"
  }
  @invalid_attrs %{}

  test "changeset with valid data" do
    changeset = User.changeset(%User{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid data" do
    changeset = User.changeset(%User{}, @invalid_attrs)
    refute changeset.valid?
  end

  test "changeset does not accept short names" do
    attrs = Map.put(@valid_attrs, :name, "U")
    changeset = User.changeset(%User{}, attrs)
    assert "should be at least 2 character(s)" in errors_on(changeset, :name)
  end

  test "changeset does not accept short password" do
    attrs = Map.put(@valid_attrs, :password, "1234567")
    changeset = User.changeset(%User{}, attrs)
    assert "should be at least 8 character(s)" in errors_on(changeset, :password)
  end

  test "changeset does not accept long password" do
    attrs = Map.put(@valid_attrs, :password, String.duplicate("q", 20))
    changeset = User.changeset(%User{}, attrs)
    assert "should be at most 16 character(s)" in errors_on(changeset, :password)
  end

  test "changeset does not accept invalid email address" do
    attrs = Map.put(@valid_attrs, :email, "wrongemail#mail.com")
    changeset = User.changeset(%User{}, attrs)
    assert "has invalid format" in errors_on(changeset, :email)
  end

  test "changeset does not accept names with special characters" do
    attrs = Map.put(@valid_attrs, :name, "wrong/4name?!")
    changeset = User.changeset(%User{}, attrs)
    assert "has invalid format" in errors_on(changeset, :name)
  end
end
