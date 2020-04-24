defmodule WraftDoc.DocumentTest do
  use WraftDoc.DataCase, async: true
  import WraftDoc.Factory
  alias WraftDoc.Account
  alias WraftDocWeb.Endpoint

  @valid_attrs %{
    "password" => "Password",
    "name" => "John Doe",
    "email" => "email@xyz.com"
  }

  @email "newemail@xyz.com"

  describe "registration/2" do
    test "user registration with valid data" do
      insert(:role, name: "user")
      organisation = insert(:organisation)
      user = Account.registration(@valid_attrs, organisation)

      assert user.name == @valid_attrs["name"]
      assert user.email == @valid_attrs["email"]
      assert user.profile.name == @valid_attrs["name"]
    end

    test "user registration with invalid data" do
      insert(:role, name: "user")
      organisation = insert(:organisation)
      {:error, changeset} = Account.registration(%{"email" => ""}, organisation)

      assert %{email: ["can't be blank"], name: ["can't be blank"], password: ["can't be blank"]} ==
               errors_on(changeset)
    end

    test "user registration with invalid email" do
      insert(:role, name: "user")
      organisation = insert(:organisation)
      params = @valid_attrs |> Map.put("email", "not an email")
      {:error, changeset} = Account.registration(params, organisation)

      assert %{email: ["has invalid format"]} == errors_on(changeset)
    end
  end

  describe "get_organisation_from_token/1" do
    test "verify and accept valid token and email" do
      organisation = insert(:organisation)

      token =
        Phoenix.Token.sign(Endpoint, "organisation_invite", %{
          organisation: organisation,
          email: @email
        })

      org = Account.get_organisation_from_token(%{"token" => token, "email" => @email})
      assert org == organisation
    end

    test "return error for valid token and different email" do
      organisation = insert(:organisation)

      token =
        Phoenix.Token.sign(Endpoint, "organisation_invite", %{
          organisation: organisation,
          email: @email
        })

      error =
        Account.get_organisation_from_token(%{"token" => token, "email" => "anotheremail@xyz.com"})

      assert error == {:error, :no_permission}
    end

    test "return error for valid token but with unexpected encoded data" do
      token =
        Phoenix.Token.sign(
          Endpoint,
          "organisation_invite",
          "expects a map with organisation and email keys, giving a string"
        )

      error = Account.get_organisation_from_token(%{"token" => token, "email" => @email})

      assert error == {:error, :no_permission}
    end

    test "return error for invalid token" do
      token = Phoenix.Token.sign(Endpoint, "different salt", "")
      error = Account.get_organisation_from_token(%{"token" => token, "email" => @email})

      assert error == {:error, :no_permission}
    end

    test "return error for expired token" do
      organisation = build(:organisation)

      token =
        Phoenix.Token.sign(
          Endpoint,
          "organisation_invite",
          %{organisation: organisation, email: @email},
          signed_at: -9_00_001
        )

      error = Account.get_organisation_from_token(%{"token" => token, "email" => @email})

      assert error == {:error, :expired}
    end
  end
end
