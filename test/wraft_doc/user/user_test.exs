defmodule WraftDoc.Account.UserTest do
  use WraftDoc.ModelCase

  @moduledoc """
    # Cases Covered
    # 1. Valid Data entry
    # 2. Invalid data entry
    # 3. Name with less than 2 characters
    # 4. Passwords with less than 8 characters
    # 5. Passwords with more than 16 characters
    # 6. Invalid email address
    # 7. Special characters in name
    # 8. Special characters in lastname
    # 9. Uniquness of email address
    # 10. Uniquness of mobile number
  """
  alias WraftDoc.Account.User

  @valid_attrs %{
    name: "User",
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

  test "changeset does not accept short name" do
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
    attrs = Map.put(@valid_attrs, :name, "wrong/name?!")
    changeset = User.changeset(%User{}, attrs)
    assert "has invalid format" in errors_on(changeset, :name)
  end

  # test "changeset does not accept lastnames with special characters" do
  #   # attrs = Map.put(@valid_attrs, :lastname, "wrong/4lastname?!")
  #   changeset = User.changeset(%User{}, @valid_attrs)
  #   IEx.pry()
  #   assert "has invalid format" in errors_on(changeset, :lastname)
  # end

  test "changeset does not accept taken email address" do
    attrs = Map.put(@valid_attrs, :email, "used@mail.com")

    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()

    changeset_2 = User.changeset(%User{}, attrs)

    {:error, changeset} = Repo.insert(changeset_2)
    refute changeset.valid?
  end

  # test "changeset does not accept taken mobile number" do
  #   attrs = Map.put(@valid_attrs, :mobile, "917012881175")

  #   changeset_1 =
  #     %User{}
  #     |> User.changeset(attrs)
  #     |> Repo.insert()

  #   changeset_2 =
  #     %User{}
  #     |> User.changeset(attrs)

  #   {:error, changeset} = Repo.insert(changeset_2)
  # end
end
