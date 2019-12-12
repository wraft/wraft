defmodule ExStarter.UserTest do
  use ExStarter.ModelCase

  @moduledoc """
    # Cases Covered
    # 1. Valid Data entry 
    # 2. Invalid data entry
    # 3. Firstname with less than 2 characters
    # 4. Passwords with less than 8 characters
    # 5. Passwords with more than 16 characters
    # 6. Invalid email address
    # 7. Special characters in firstname
    # 8. Special characters in lastname
    # 9. Uniquness of email address
    # 10. Uniquness of mobile number
  """
  alias ExStarter.UserManagement
  alias ExStarter.UserManagement.User

  @valid_attrs %{
    firstname: "User",
    lastname: "Name",
    email: "user@mail.com",
    password: "123456789",
    mobile: "918943650799",
    country: "IN"
  }
  # Test fails without mobile and country key in invalid attrs.
  @invalid_attrs %{mobile: "+9386ew6gqwe", country: "90"}

  test "changeset with valid data" do
    changeset = User.changeset(%User{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid data" do
    changeset = User.changeset(%User{}, @invalid_attrs)
    refute changeset.valid?
  end

  test "changeset does not accept short firstnames" do
    attrs = Map.put(@valid_attrs, :firstname, "U")
    changeset = User.changeset(%User{}, attrs)
    assert "should be at least 2 character(s)" in errors_on(changeset, :firstname)
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

  test "changeset does not accept firstnames with special characters" do
    attrs = Map.put(@valid_attrs, :firstname, "wrong/4firstname?!")
    changeset = User.changeset(%User{}, attrs)
    assert "has invalid format" in errors_on(changeset, :firstname)
  end

  test "changeset does not accept lastnames with special characters" do
    attrs = Map.put(@valid_attrs, :lastname, "wrong/4lastname?!")
    changeset = User.changeset(%User{}, attrs)
    assert "has invalid format" in errors_on(changeset, :lastname)
  end

  test "changeset does not accept taken email address" do
    attrs = Map.put(@valid_attrs, :email, "used@mail.com")

    changeset_1 =
      %User{}
      |> User.changeset(attrs)
      |> Repo.insert()

    changeset_2 =
      %User{}
      |> User.changeset(attrs)

    {:error, changeset} = Repo.insert(changeset_2)
    refute changeset.valid?
  end

  test "changeset does not accept taken mobile number" do
    attrs = Map.put(@valid_attrs, :mobile, "917012881175")

    changeset_1 =
      %User{}
      |> User.changeset(attrs)
      |> Repo.insert()

    changeset_2 =
      %User{}
      |> User.changeset(attrs)

    {:error, changeset} = Repo.insert(changeset_2)
  end
end
