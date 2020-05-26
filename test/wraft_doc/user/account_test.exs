defmodule WraftDoc.AccountTest do
  use WraftDoc.DataCase, async: true
  import WraftDoc.Factory
  alias WraftDoc.{Repo, Account, Account.AuthToken}
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

    test "returns not found when params doens't contain token or email or both" do
      resp1 = Account.get_organisation_from_token(%{"token" => nil})
      resp2 = Account.get_organisation_from_token(%{"email" => nil})
      resp3 = Account.get_organisation_from_token(%{})
      assert resp1 == nil
      assert resp2 == nil
      assert resp3 == nil
    end
  end

  describe "create_profile/2" do
    test "create profile for a user with valid attrs" do
      user = insert(:user)
      {:ok, dob} = Date.new(2020, 2, 29)
      params = %{name: user.name, dob: dob, gender: "Male"}
      {:ok, profile} = Account.create_profile(user, params)
      assert profile.name == user.name
      assert profile.dob == dob
      assert profile.gender == "Male"
    end

    test "return error on creating profile for a user with invalid attrs" do
      user = insert(:user)
      {:error, changeset} = Account.create_profile(user, %{})
      assert %{name: ["can't be blank"]} == errors_on(changeset)
    end
  end

  describe "find/1" do
    test "get user when correct email is provided" do
      user = insert(:user)
      found_user = Account.find(user.email)

      assert user.email == found_user.email
      assert user.id == found_user.id
      assert user.uuid == found_user.uuid
    end

    test "returns error when incorrect email is provided" do
      found_user = Account.find("nouser@xyz.com")
      assert found_user == {:error, :invalid}
    end

    test "return error when invalid data is provided" do
      found_user = Account.find(123)
      assert found_user == {:error, :invalid}
    end
  end

  describe "authenticate/1" do
    test "successfully authenticate when correct password is given" do
      user = insert(:user)
      response = Account.authenticate(%{user: user, password: "encrypt"})
      assert tuple_size(response) == 3
      assert elem(response, 0) == :ok
    end

    test "does not authenticate when nil or empty password is given" do
      user = insert(:user)
      response1 = Account.authenticate(%{user: user, password: ""})
      response2 = Account.authenticate(%{user: user, password: nil})
      assert response1 == {:error, :no_data}
      assert response2 == {:error, :no_data}
    end

    test "does not authenticate when incorrect password is given" do
      user = insert(:user)
      response = Account.authenticate(%{user: user, password: "inorrectpassword"})
      assert response == {:error, :invalid}
    end
  end

  describe "update_profile/2" do
    test "update profile with valid attrs" do
      profile = insert(:profile, gender: "Female", dob: "1998-04-01")
      params = %{name: "new name", dob: "1990-01-22", gender: "Male"}
      profile = Account.update_profile(profile.user, params)

      assert profile.name == "new name"
      assert profile.user.name == "new name"
      assert profile.dob == ~D[1990-01-22]
      assert profile.gender == "Male"
    end

    test "update profile with invalid attrs" do
      profile = insert(:profile)
      params = %{name: "", dob: "1990", gender: 1}
      {:error, :profile, changeset, %{}} = Account.update_profile(profile.user, params)

      assert %{name: ["can't be blank"], dob: ["is invalid"], gender: ["is invalid"]} ==
               errors_on(changeset)
    end
  end

  describe "get_profile/1" do
    test "get profile when correct UUID is given" do
      profile = insert(:profile)
      response = Account.get_profile(profile.uuid)
      refute response == nil
      assert response.uuid == profile.uuid
    end

    test "return nil when incorrect UUID is given" do
      response = Account.get_profile(Ecto.UUID.generate())
      assert response == nil
    end

    test "return nil when a non-UUID value is given" do
      response = Account.get_profile(1)
      assert response == nil
    end
  end

  describe "delete_profile/1" do
    test "successfully delete profile when profile struct is given" do
      profile = insert(:profile)
      {:ok, deleted_profile} = Account.delete_profile(profile)
      fetched_deleted_profile = Account.get_profile(profile.uuid)
      assert deleted_profile.uuid == profile.uuid
      assert fetched_deleted_profile == nil
    end

    test "return nil when given value is not a profile struct" do
      response = Account.delete_profile(1)
      assert response == nil
    end
  end

  describe "get_role_from_uuid/1" do
    test "get role when correct UUID is given" do
      role = insert(:role)
      response = Account.get_role_from_uuid(role.uuid)
      refute response == nil
      assert response == role
    end

    test "return nil when incorrect UUID is given" do
      response = Account.get_role_from_uuid(Ecto.UUID.generate())
      assert response == nil
    end

    test "return nil when non-UUID value is given" do
      response = Account.get_role_from_uuid(1)
      assert response == nil
    end
  end

  describe "get_user_by_uuid/1" do
    test "get user when correct UUID is given" do
      user = insert(:user)
      response = Account.get_user_by_uuid(user.uuid)
      refute response == nil
      assert response.uuid == user.uuid
      assert response.name == user.name
    end

    test "return nil when incorrect UUID is given" do
      response = Account.get_user_by_uuid(Ecto.UUID.generate())
      assert response == nil
    end

    test "return nil when non-UUID value is given" do
      response = Account.get_user_by_uuid(1)
      assert response == nil
    end
  end

  describe "create_token/1" do
    test "create token when the email of a valid user is given" do
      user = insert(:user)
      token = Account.create_token(%{"email" => user.email})
      refute token.value == nil
      assert token.user.email == user.email
      assert token.token_type == "password_verify"
    end

    test "return error when the email given is not of valid user" do
      response = Account.create_token(%{"email" => "testamail@xyz.com"})
      assert response == {:error, :invalid_email}
    end

    test "return error for invalid attrs" do
      response = Account.create_token(%{})
      assert response == {:error, :invalid_email}
    end
  end

  describe "check_token/1" do
    test "test when valid token is given" do
      user = insert(:user)
      auth_token = Account.create_token(%{"email" => user.email})
      response = Account.check_token(auth_token.value)
      assert response.value == auth_token.value
      assert response.token_type == auth_token.token_type
      assert response.expiry_datetime == auth_token.expiry_datetime
      assert response.user_id == auth_token.user_id
    end

    test "test when invalid token is given" do
      value = Phoenix.Token.sign(WraftDocWeb.Endpoint, "invalid", "email") |> Base.url_encode64()
      auth_token = insert(:auth_token, value: value, token_type: "password_verify")
      response = Account.check_token(auth_token.value)
      assert response == {:error, :fake}
    end

    test "test when expired token is given" do
      value =
        Phoenix.Token.sign(WraftDocWeb.Endpoint, "reset", "email", signed_at: -861)
        |> Base.url_encode64()

      auth_token = insert(:auth_token, value: value, token_type: "password_verify")
      response = Account.check_token(auth_token.value)
      assert response == {:error, :expired}
    end

    test "test when token does not exist" do
      response = Account.check_token("invalid token")
      assert response == {:error, :fake}
    end
  end

  describe "reset_password/1" do
    test "update user password when valid token and password are given" do
      user = insert(:user)
      auth_token = Account.create_token(%{"email" => user.email})
      params = %{"token" => auth_token.value, "password" => "newpassword"}
      updated_user = Account.reset_password(params)
      assert Bcrypt.verify_pass("newpassword", updated_user.encrypted_password) == true
    end

    test "does not update user password when password is not valid" do
      user = insert(:user)
      auth_token = Account.create_token(%{"email" => user.email})
      params = %{"token" => auth_token.value, "password" => "invalid"}
      {:error, changeset} = Account.reset_password(params)
      assert %{password: ["should be at least 8 character(s)"]} == errors_on(changeset)
    end

    test "return error when token is invalid" do
      value = Phoenix.Token.sign(WraftDocWeb.Endpoint, "invalid", "email") |> Base.url_encode64()
      auth_token = insert(:auth_token, value: value, token_type: "password_verify")
      params = %{"token" => auth_token.value, "password" => "newpassword"}
      response = Account.reset_password(params)
      assert response == {:error, :fake}
    end
  end

  describe "update_password/2" do
    test "updates password with valid attrs" do
      user = insert(:user)
      params = %{"current_password" => "encrypt", "password" => "newpassword"}
      updated_user = Account.update_password(user, params)
      assert Bcrypt.verify_pass("newpassword", updated_user.encrypted_password) == true
    end

    test "does not update with invalid attrs" do
      user = insert(:user)
      params = %{"current_password" => "encrypt", "password" => "invalid"}
      {:error, changeset} = Account.update_password(user, params)
      assert %{password: ["should be at least 8 character(s)"]} == errors_on(changeset)
    end

    test "does not update with wrong current password" do
      user = insert(:user)
      params = %{"current_password" => "wrongcurrentpassword", "password" => "123123123"}
      response = Account.update_password(user, params)
      assert response == {:error, :invalid_password}
    end

    test "does not update with same password" do
      user = insert(:user)
      params = %{"current_password" => "encrypt", "password" => "encrypt"}
      response = Account.update_password(user, params)
      assert response == {:error, :same_password}
    end
  end
end
