defmodule WraftDoc.AccountTest do
  use WraftDoc.DataCase, async: true
  alias WraftDoc.Account
  alias WraftDoc.Account.AuthToken

  @moduletag :account
  @valid_attrs %{
    "password" => "Password",
    "name" => "John Doe",
    "email" => "email@xyz.com"
  }

  @email "newemail@xyz.com"

  describe "registration/1" do
    test "user successfully registers with valid data and without organisation token" do
      insert(:role, name: "user")
      insert(:plan, name: "Free Trial")

      {:ok, %{user: user, organisations: [personal_org]}} = Account.registration(@valid_attrs)

      assert user.name == @valid_attrs["name"]
      assert user.email == @valid_attrs["email"]
      assert personal_org.name == "Personal"
    end

    test "user successfully registers with valid data and an organisation invite token" do
      role = insert(:role, name: "user")
      insert(:plan, name: "Free Trial")

      organisation = insert(:organisation)

      token =
        WraftDoc.create_phx_token("organisation_invite", %{
          organisation_id: organisation.id,
          email: @valid_attrs["email"],
          role: role.name
        })

      insert(:auth_token, value: token, token_type: "invite")

      params = Map.put(@valid_attrs, "token", token)

      {:ok, %{user: user, organisations: [personal_org, invited_org]}} =
        Account.registration(params)

      assert user.name == @valid_attrs["name"]
      assert user.email == @valid_attrs["email"]
      assert personal_org.name == "Personal"
      assert invited_org.name == organisation.name
    end

    test "returns error changeset with invalid data" do
      insert(:role, name: "user")
      {:error, changeset} = Account.registration(%{"email" => ""})

      assert %{email: ["can't be blank"], name: ["can't be blank"], password: ["can't be blank"]} ==
               errors_on(changeset)
    end

    test "returns error with invalid email" do
      insert(:role, name: "user")
      params = Map.put(@valid_attrs, "email", "not an email")
      {:error, changeset} = Account.registration(params)

      assert %{email: ["has invalid format"]} == errors_on(changeset)
    end

    test "returns error for invalid organisation" do
      organisation = insert(:organisation)

      token =
        WraftDoc.create_phx_token("different salt", %{
          organisation_id: organisation.id,
          email: @email,
          role: "user"
        })

      insert(:auth_token, value: token, token_type: "invite")
      params = Map.put(@valid_attrs, "token", token)

      error = Account.registration(params)

      assert error == {:error, :fake}
    end
  end

  describe "get_organisation_from_token/1" do
    test "verify and accept valid token and email" do
      organisation = insert(:organisation)

      token =
        WraftDoc.create_phx_token("organisation_invite", %{
          organisation_id: organisation.id,
          email: @email,
          role: "user"
        })

      insert(:auth_token, value: token, token_type: "invite")

      {:ok, ^organisation, %{"token" => ^token, "email" => @email, "role" => "user"}} =
        Account.get_organisation_from_token(%{"token" => token, "email" => @email})
    end

    test "return error for valid token and different email" do
      organisation = insert(:organisation)

      token =
        WraftDoc.create_phx_token("organisation_invite", %{
          organisation_id: organisation.id,
          email: @email,
          role: "user"
        })

      insert(:auth_token, value: token, token_type: "invite")

      error =
        Account.get_organisation_from_token(%{"token" => token, "email" => "anotheremail@xyz.com"})

      assert error == {:error, :no_permission}
    end

    test "return error for valid token but with unexpected encoded data" do
      token =
        WraftDoc.create_phx_token(
          "organisation_invite",
          "expects a map with organisation, email and role keys, giving a string"
        )

      insert(:auth_token, value: token, token_type: "invite")
      error = Account.get_organisation_from_token(%{"token" => token, "email" => @email})

      assert error == {:error, :no_permission}
    end

    test "return error for invalid token" do
      organisation = insert(:organisation)

      token =
        WraftDoc.create_phx_token("different salt", %{
          organisation_id: organisation.id,
          email: @email,
          role: "user"
        })

      insert(:auth_token, value: token, token_type: "invite")
      error = Account.get_organisation_from_token(%{"token" => token, "email" => @email})

      assert error == {:error, :fake}
    end

    test "return error when token does not exist" do
      organisation = insert(:organisation)

      token =
        WraftDoc.create_phx_token("organisation_invite", %{
          organisation_id: organisation.id,
          email: @email,
          role: "user"
        })

      error = Account.get_organisation_from_token(%{"token" => token, "email" => @email})

      assert error == {:error, :fake}
    end

    test "return error for expired token" do
      organisation = build(:organisation)

      token =
        WraftDoc.create_phx_token(
          "organisation_invite",
          %{
            organisation_id: organisation.id,
            email: @email,
            role: "user"
          },
          signed_at: -900_001
        )

      insert(:auth_token, value: token, token_type: "invite")
      error = Account.get_organisation_from_token(%{"token" => token, "email" => @email})

      assert error == {:error, :expired}
    end

    test "returns not found when params doesn't contain token or email or both" do
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

  @tag :authenticate
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
      {:error, changeset} = Account.update_profile(profile.user, params)

      assert %{name: ["can't be blank"], dob: ["is invalid"], gender: ["is invalid"]} ==
               errors_on(changeset)
    end
  end

  describe "get_profile/1" do
    test "get profile when correct UUID is given" do
      profile = insert(:profile)
      response = Account.get_profile(profile.id)
      refute response == nil
      assert response.id == profile.id
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
      fetched_deleted_profile = Account.get_profile(profile.id)
      assert deleted_profile.id == profile.id
      assert fetched_deleted_profile == nil
    end

    test "return nil when given value is not a profile struct" do
      response = Account.delete_profile(1)
      assert response == nil
    end
  end

  describe "get_user_by_uuid/1" do
    test "get user when correct UUID is given" do
      user = insert(:user)
      response = Account.get_user_by_uuid(user.id)
      refute response == nil

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

  describe "create_password_token/1" do
    test "create token when the email of a valid user is given" do
      user = insert(:user)
      token = Account.create_password_token(%{"email" => user.email})
      refute token.value == nil
      assert token.user.email == user.email
      assert token.token_type == :password_verify
    end

    test "return error when the email given is not of valid user" do
      response = Account.create_password_token(%{"email" => "testamail@xyz.com"})
      assert response == {:error, :invalid_email}
    end

    test "return error for invalid attrs" do
      response = Account.create_password_token(%{})
      assert response == {:error, :invalid_email}
    end
  end

  describe "check_token/2" do
    test "test when valid token is given" do
      user = insert(:user)
      auth_token = Account.create_password_token(%{"email" => user.email})
      response = Account.check_token(auth_token.value, :password_verify)
      assert response.value == auth_token.value
      assert response.token_type == auth_token.token_type
      assert response.expiry_datetime == auth_token.expiry_datetime
      assert response.user_id == auth_token.user_id
    end

    test "returns the payload and not auth token with valid token for invite token type" do
      user = insert(:user)
      email = Faker.Internet.email()
      org_id = Faker.UUID.v4()

      token =
        WraftDoc.create_phx_token("organisation_invite", %{organisation_id: org_id, email: email})

      Account.insert_auth_token!(user, %{value: token, token_type: "invite"})

      assert {:ok, response} = Account.check_token(token, :invite)
      assert %{organisation_id: org_id, email: email} == response
    end

    test "test when invalid token is given" do
      value = WraftDoc.create_phx_token("invalid", "email")
      auth_token = insert(:auth_token, value: value, token_type: "password_verify")
      response = Account.check_token(auth_token.value, :password_verify)
      assert response == {:error, :fake}
    end

    test "test when expired token is given" do
      value = WraftDoc.create_phx_token("reset", "email", signed_at: -861)

      auth_token = insert(:auth_token, value: value, token_type: "password_verify")
      response = Account.check_token(auth_token.value, :password_verify)
      assert response == {:error, :expired}
    end

    test "test when token does not exist" do
      response = Account.check_token("invalid_token", :password_verify)
      assert response == {:error, :fake}
    end
  end

  describe "insert_auth_token!/2" do
    test "inserts new auth token with valid params" do
      user = insert(:user)
      params = %{value: "value", token_type: "invite"}
      assert %AuthToken{} = auth_token = Account.insert_auth_token!(user, params)
      assert [^auth_token] = Repo.all(AuthToken)
    end

    test "raises with invalid params" do
      user = insert(:user)
      params = %{value: "value", token_type: "wrong"}
      assert_raise(Ecto.InvalidChangesetError, fn -> Account.insert_auth_token!(user, params) end)
    end

    test "raises with invalid arguments" do
      params = %{value: "value", token_type: "invite"}

      assert_raise(RuntimeError, "Unexpected arguments passed.", fn ->
        Account.insert_auth_token!("invalid", params)
      end)
    end
  end

  describe "delete_auth_token!/1" do
    test "deletes the given auth token" do
      auth_token = insert(:auth_token)
      deleted_auth_token = Account.delete_auth_token!(auth_token)

      assert auth_token.id == deleted_auth_token.id
      assert [] == Repo.all(AuthToken)
    end

    test "deletes the auth token with the given value" do
      auth_token = insert(:auth_token)
      deleted_auth_token = Account.delete_auth_token!(auth_token.value)

      assert auth_token.id == deleted_auth_token.id
      assert [] == Repo.all(AuthToken)
    end

    test "raises with non existing auth token" do
      auth_token = insert(:auth_token)
      assert Account.delete_auth_token!(auth_token)
      assert_raise(Ecto.StaleEntryError, fn -> Account.delete_auth_token!(auth_token) end)
    end

    test "raises with non existing auth token value" do
      assert_raise(BadMapError, fn -> Account.delete_auth_token!("non-exitest-token") end)
    end
  end

  describe "delete_auth_token/2" do
    test "deletes all auth tokens of given type belonging to the given user ID" do
      user = insert(:user)
      auth_token1 = insert(:auth_token, token_type: "password_verify", user: user)
      auth_token2 = insert(:auth_token, token_type: "password_verify", user: user)

      auth_token3 = insert(:auth_token, token_type: "invite", user: user)
      auth_token4 = insert(:auth_token)

      assert {2, nil} = Account.delete_auth_token(user.id, "password_verify")

      auth_token_ids = AuthToken |> Repo.all() |> Enum.map(& &1.id) |> Enum.sort()

      refute Enum.member?(auth_token_ids, auth_token1.id)
      refute Enum.member?(auth_token_ids, auth_token2.id)
      assert Enum.sort([auth_token3.id, auth_token4.id]) == auth_token_ids
    end
  end

  describe "reset_password/1" do
    test "update user password when valid token and password are given" do
      user = insert(:user)
      auth_token = Account.create_password_token(%{"email" => user.email})
      params = %{"token" => auth_token.value, "password" => "newpassword"}
      updated_user = Account.reset_password(params)
      assert Bcrypt.verify_pass("newpassword", updated_user.encrypted_password) == true
    end

    test "does not update user password when password is not valid" do
      user = insert(:user)
      auth_token = Account.create_password_token(%{"email" => user.email})
      params = %{"token" => auth_token.value, "password" => "invalid"}
      {:error, changeset} = Account.reset_password(params)
      assert %{password: ["should be at least 8 character(s)"]} == errors_on(changeset)
    end

    test "return error when token is invalid" do
      value = WraftDoc.create_phx_token("invalid", "email")
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
