defmodule WraftDoc.WaitingLists.WaitingListTest do
  @moduledoc """
  Test WaitList Schema
  """
  use WraftDoc.ModelCase
  import Ecto.Changeset, only: [traverse_errors: 2]
  import WraftDoc.Factory
  @moduletag :waiting_list

  alias WraftDoc.Repo
  alias WraftDoc.WaitingLists.WaitingList

  @valid_attrs %{
    first_name: "first name",
    last_name: "last name",
    email: "sample@gmail.com",
    status: "pending"
  }

  @invalid_attrs %{}

  describe "changeset/2" do
    test "create a valid changeset with invalid attribute" do
      changeset = WaitingList.changeset(%WaitingList{}, @invalid_attrs)
      refute changeset.valid?
    end

    test "creates a valid changeset with valid attribute" do
      changeset = WaitingList.changeset(%WaitingList{}, @valid_attrs)
      assert changeset.valid?
    end

    test "validates email is unique" do
      insert(:waiting_list, email: "sample@gmail.com")

      {:error, changeset} = %WaitingList{} |> WaitingList.changeset(@valid_attrs) |> Repo.insert()

      assert %{email: ["User with this email already in waiting list."]} ==
               traverse_errors(changeset, fn {msg, _opts} -> msg end)
    end

    test "does not accept email without @ symbol in email string" do
      params = Map.replace(@valid_attrs, :email, "samplegmail.com")
      changeset = WaitingList.changeset(%WaitingList{}, params)
      assert %{email: ["invalid email"]} == traverse_errors(changeset, fn {msg, _opts} -> msg end)
    end

    test "does not accept email if there are spaces in the email string" do
      params = Map.replace(@valid_attrs, :email, "sample @ gmail.com")
      changeset = WaitingList.changeset(%WaitingList{}, params)
      assert %{email: ["invalid email"]} == traverse_errors(changeset, fn {msg, _opts} -> msg end)
    end

    test "does not accept email if there is no characters after dot" do
      params = Map.replace(@valid_attrs, :email, "sample@gmail.")
      changeset = WaitingList.changeset(%WaitingList{}, params)
      assert %{email: ["invalid email"]} == traverse_errors(changeset, fn {msg, _opts} -> msg end)
    end

    test "does not accept email if there is no dotin the email string" do
      params = Map.replace(@valid_attrs, :email, "sample@gmailcom")
      changeset = WaitingList.changeset(%WaitingList{}, params)
      assert %{email: ["invalid email"]} == traverse_errors(changeset, fn {msg, _opts} -> msg end)
    end
  end
end
