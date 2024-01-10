defmodule WraftDoc.AccountTest do
  use WraftDoc.DataCase, async: true

  alias WraftDoc.Account
  alias WraftDoc.Account.Role
  alias WraftDoc.Account.User
  alias WraftDoc.Account.UserOrganisation
  alias WraftDoc.Account.UserRole
  alias WraftDoc.AuthTokens
  alias WraftDoc.Enterprise.Organisation
  alias WraftDoc.InvitedUsers
  alias WraftDoc.InvitedUsers.InvitedUser
  alias WraftDoc.Workers.DefaultWorker
  alias WraftDoc.Workers.EmailWorker
  alias WraftDocWeb.Guardian

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

      {:ok, %{user: user, organisations: [personal_org]}} = Account.registration(@valid_attrs)

      assert user.name == @valid_attrs["name"]
      assert user.email == @valid_attrs["email"]
      assert personal_org.name == "Personal"
    end

    test "user successfully registers with valid data and an organisation invite token" do
      organisation = insert(:organisation)

      role_ids =
        ["user", "admin"]
        |> Enum.map(&insert(:role, name: &1, organisation: organisation))
        |> Enum.map(& &1.id)
        |> Enum.sort()

      token =
        WraftDoc.create_phx_token("organisation_invite", %{
          organisation_id: organisation.id,
          email: @valid_attrs["email"],
          roles: role_ids
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
      {:error, changeset} = Account.registration(%{"email" => ""})

      assert %{email: ["can't be blank"], name: ["can't be blank"], password: ["can't be blank"]} ==
               errors_on(changeset)
    end

    test "returns error with invalid email" do
      params = Map.put(@valid_attrs, "email", "not an email")
      {:error, changeset} = Account.registration(params)

      assert %{email: ["has invalid format"]} == errors_on(changeset)
    end

    test "returns error for invalid organisation" do
      organisation = insert(:organisation)
      role = insert(:role, organisation: organisation)

      token =
        WraftDoc.create_phx_token("different salt", %{
          organisation_id: organisation.id,
          email: @email,
          roles: [role.id]
        })

      insert(:auth_token, value: token, token_type: "invite")
      params = Map.put(@valid_attrs, "token", token)

      error = Account.registration(params)

      assert error == {:error, :fake}
    end

    test "updates the invited user status to \"joined\" when an invited user successfully registers" do
      organisation = insert(:organisation)
      role = insert(:role, name: "user", organisation: organisation)

      token =
        WraftDoc.create_phx_token("organisation_invite", %{
          organisation_id: organisation.id,
          email: @valid_attrs["email"],
          roles: [role.id]
        })

      insert(:auth_token, value: token, token_type: "invite")

      params = Map.put(@valid_attrs, "token", token)

      invited_user =
        insert(:invited_user, email: @valid_attrs["email"], organisation: organisation)

      {:ok, %{user: _user, organisations: [_personal, _invited]}} = Account.registration(params)

      assert %InvitedUser{status: "joined"} =
               InvitedUsers.get_invited_user(invited_user.email, invited_user.organisation_id)
    end

    test "updates the invited user status to \"expired\" when the invitation token is expired" do
      organisation = insert(:organisation)
      role = insert(:role, name: "user", organisation: organisation)

      token =
        WraftDoc.create_phx_token(
          "organisation_invite",
          %{
            organisation_id: organisation.id,
            email: @valid_attrs["email"],
            roles: [role.id]
          },
          signed_at: -900_000
        )

      insert(:auth_token, value: token, token_type: "invite")

      params = Map.put(@valid_attrs, "token", token)

      invited_user =
        insert(:invited_user, email: @valid_attrs["email"], organisation: organisation)

      assert {:error, :expired} == Account.registration(params)

      assert %InvitedUser{status: "expired"} =
               InvitedUsers.get_invited_user(invited_user.email, invited_user.organisation_id)
    end

    test "creates an oban job to create the default roles in personal organisations" do
      insert(:role, name: "user")

      {:ok, %{user: user, organisations: [personal_org]}} = Account.registration(@valid_attrs)

      assert user.name == @valid_attrs["name"]
      assert user.email == @valid_attrs["email"]
      assert personal_org.name == "Personal"

      assert_enqueued(
        worker: DefaultWorker,
        tags: ["personal_organisation_roles"],
        args: %{organisation_id: personal_org.id, user_id: user.id},
        queue: :default
      )
    end

    test "creates an oban job to assign roles for the user in the invited organisation" do
      organisation = insert(:organisation)

      role_ids =
        ["user", "admin"]
        |> Enum.map(&insert(:role, name: &1, organisation: organisation))
        |> Enum.map(& &1.id)
        |> Enum.sort()

      token =
        WraftDoc.create_phx_token("organisation_invite", %{
          organisation_id: organisation.id,
          email: @valid_attrs["email"],
          roles: role_ids
        })

      insert(:auth_token, value: token, token_type: "invite")
      params = Map.put(@valid_attrs, "token", token)

      {:ok, %{user: user}} = Account.registration(params)

      assert_enqueued(
        worker: DefaultWorker,
        tags: ["assign_role"],
        args: %{roles: role_ids, user_id: user.id},
        queue: :default
      )

      assert :ok =
               perform_job(DefaultWorker, %{roles: role_ids, user_id: user.id},
                 tags: ["assign_role"]
               )

      assert role_ids ==
               user
               |> Repo.preload(:roles, force: true)
               |> Map.get(:roles)
               |> Enum.map(& &1.id)
               |> Enum.sort()
    end

    test "creates a user_organisation entry for personal organisation" do
      insert(:role, name: "user")

      {:ok, %{user: user, organisations: [personal_org]}} = Account.registration(@valid_attrs)

      assert %UserOrganisation{} =
               Repo.get_by(UserOrganisation, user_id: user.id, organisation_id: personal_org.id)
    end

    test "creates a user_organisation entry for invited organisation" do
      organisation = insert(:organisation)
      role = insert(:role, name: "user", organisation: organisation)

      token =
        WraftDoc.create_phx_token("organisation_invite", %{
          organisation_id: organisation.id,
          email: @valid_attrs["email"],
          roles: [role.id]
        })

      insert(:auth_token, value: token, token_type: "invite")

      params = Map.put(@valid_attrs, "token", token)

      {:ok, %{user: user, organisations: [_personal_org, invited_org]}} =
        Account.registration(params)

      assert %UserOrganisation{} =
               Repo.get_by(UserOrganisation, user_id: user.id, organisation_id: invited_org.id)
    end
  end

  describe "create_user_role/2" do
    test "creates a user_role with valid input" do
      %{id: user_id} = insert(:user)
      %{id: role_id} = insert(:role)

      assert {:ok, %UserRole{user_id: ^user_id, role_id: ^role_id}} =
               Account.create_user_role(user_id, role_id)
    end

    test "raises with invalid input" do
      assert_raise(Ecto.ChangeError, fn -> Account.create_user_role("invalid", "role_id") end)
    end
  end

  describe "get_user_role/3" do
    test "returns the user_role with valid input" do
      %{owned_organisations: [organisation]} = current_user = insert(:user_with_organisation)
      role = insert(:role, organisation: organisation)
      %{role_id: role_id, user_id: user_id} = insert(:user_role, role: role)

      assert %UserRole{} = Account.get_user_role(current_user, user_id, role_id)
    end

    test "returns nil with user_role that does not belong to current user's organisation" do
      current_user = insert(:user_with_organisation)
      %{role_id: role_id, user_id: user_id} = insert(:user_role)

      assert nil == Account.get_user_role(current_user, user_id, role_id)
    end
  end

  describe "delete_user_role/2" do
    test "deletes a user_role with valid input" do
      user_role = insert(:user_role)
      user_id = user_role.user_id
      role_id = user_role.role_id

      assert {:ok, %UserRole{user_id: ^user_id, role_id: ^role_id}} =
               Account.delete_user_role(user_role)
    end

    test "raises with invalid input" do
      assert_raise(BadMapError, fn -> Account.delete_user_role("invalid") end)
    end
  end

  describe "get_role/1" do
    test "gets a role with valid ID" do
      %Role{id: id} = insert(:role)
      assert %Role{id: ^id} = Account.get_role(id)
    end

    test "returns nil with non-existent ID" do
      assert nil == Account.get_role(Faker.UUID.v4())
    end

    test "returns nil with invalid ID" do
      assert nil == Account.get_role("invalid")
    end
  end

  describe "get_role/2" do
    test "returns the role with valid role ID and current organisation ID in user struct" do
      user = insert(:user_with_organisation)
      [organisation] = user.owned_organisations
      %Role{id: id} = insert(:role, organisation: organisation)

      assert %Role{id: ^id} = Account.get_role(user, id)
    end

    test "returns the role with valid role ID and organisation ID in organisation struct" do
      organisation = insert(:organisation)
      %Role{id: id} = insert(:role, organisation: organisation)

      assert %Role{id: ^id} = Account.get_role(organisation, id)
    end

    test "returns nil in any other case" do
      assert nil == Account.get_role("organisation", "id")
    end
  end

  describe "create_role/2" do
    test "creates a role and preloads organisation with valid params" do
      user = insert(:user_with_organisation)
      organisation_id = user.current_org_id
      params = %{"name" => "new role", "permissions" => ["members:manage"]}

      role = Account.create_role(user, params)
      assert %Role{name: "new role", permissions: ["members:manage"]} = role
      assert %Organisation{id: ^organisation_id} = role.organisation
    end

    test "returns error changeset with invalid params" do
      user = insert(:user_with_organisation)
      params = %{"name" => "new role", "permissions" => "members:manage"}

      assert {:error, %Ecto.Changeset{} = changeset} = Account.create_role(user, params)
      assert %{permissions: ["is invalid"]} == errors_on(changeset)
    end
  end

  describe "update_role/2" do
    test "updates a role and preloads organisation with valid params" do
      role = insert(:role, permissions: ["manage:invite"])
      params = %{name: "admin", permissions: ["members:invite", "role:manage"]}

      role = Account.update_role(role, params)

      assert %Role{name: "admin", permissions: ["members:invite", "role:manage"]} = role
      assert %Organisation{id: _} = role.organisation
    end

    test "returns error changeset with invalid params" do
      role = insert(:role, permissions: ["manage:invite"])
      params = %{name: nil, permissions: ["members:manage"]}

      assert {:error, %Ecto.Changeset{} = changeset} = Account.update_role(role, params)
      assert %{name: ["can't be blank"]} == errors_on(changeset)
    end
  end

  describe "delete_role/1" do
    test "returns the role after deleting the role" do
      role = insert(:role)
      assert {:ok, %Role{}} = Account.delete_role(role)
      assert nil == Repo.get(Role, role.id)
    end

    test "raises with invalid role" do
      assert_raise(BadMapError, fn -> Account.delete_role(nil) end)
    end

    test "returns error on attempting to delete superadmin role" do
      role = insert(:role, name: "superadmin")
      assert {:error, :no_permission} = Account.delete_role(role)
    end
  end

  describe "get_organisation_and_role_from_token/1" do
    test "verify and accept valid token and email" do
      organisation = insert(:organisation)
      %{id: organisation_id} = organisation
      %{id: role_id} = role = insert(:role, organisation: organisation)

      token =
        WraftDoc.create_phx_token("organisation_invite", %{
          organisation_id: organisation.id,
          email: @email,
          roles: [role.id]
        })

      insert(:auth_token, value: token, token_type: "invite")

      {:ok, %{organisation: %Organisation{id: ^organisation_id}, role_ids: [^role_id]}} =
        Account.get_organisation_and_role_from_token(%{
          "token" => token,
          "email" => @email
        })
    end

    test "return error for valid token and different email" do
      organisation = insert(:organisation)
      role = insert(:role, organisation: organisation)

      token =
        WraftDoc.create_phx_token("organisation_invite", %{
          organisation_id: organisation.id,
          email: @email,
          role: role.id
        })

      insert(:auth_token, value: token, token_type: "invite")

      error =
        Account.get_organisation_and_role_from_token(%{
          "token" => token,
          "email" => "anotheremail@xyz.com"
        })

      assert error == {:error, :no_permission}
    end

    test "return error for valid token but with unexpected encoded data" do
      token =
        WraftDoc.create_phx_token(
          "organisation_invite",
          "expects a map with organisation, email and role keys, giving a string"
        )

      insert(:auth_token, value: token, token_type: "invite")
      error = Account.get_organisation_and_role_from_token(%{"token" => token, "email" => @email})

      assert error == {:error, :no_permission}
    end

    test "return {:error, :no_permission} for valid token but role encoded in token" <>
           "does not belong to the organisation encoded in token" do
      organisation = insert(:organisation)
      role = insert(:role)

      token =
        WraftDoc.create_phx_token("organisation_invite", %{
          organisation_id: organisation.id,
          email: @email,
          role: role.id
        })

      insert(:auth_token, value: token, token_type: "invite")
      error = Account.get_organisation_and_role_from_token(%{"token" => token, "email" => @email})

      assert error == {:error, :no_permission}
    end

    test "return error for invalid token" do
      organisation = insert(:organisation)
      role = insert(:role, organisation: organisation)

      token =
        WraftDoc.create_phx_token("different salt", %{
          organisation_id: organisation.id,
          email: @email,
          role: role.id
        })

      insert(:auth_token, value: token, token_type: "invite")
      error = Account.get_organisation_and_role_from_token(%{"token" => token, "email" => @email})

      assert error == {:error, :fake}
    end

    test "return error when token does not exist" do
      organisation = insert(:organisation)
      role = insert(:role, organisation: organisation)

      token =
        WraftDoc.create_phx_token("organisation_invite", %{
          organisation_id: organisation.id,
          email: @email,
          role: role.id
        })

      error = Account.get_organisation_and_role_from_token(%{"token" => token, "email" => @email})

      assert error == {:error, :fake}
    end

    test "return error for expired token" do
      organisation = insert(:organisation)
      role = insert(:role, organisation: organisation)

      token =
        WraftDoc.create_phx_token(
          "organisation_invite",
          %{
            organisation_id: role.organisation.id,
            email: @email,
            role: role.id
          },
          signed_at: -900_001
        )

      insert(:auth_token, value: token, token_type: "invite")
      error = Account.get_organisation_and_role_from_token(%{"token" => token, "email" => @email})

      assert error == {:error, :expired}
    end

    test "returns not found when params doesn't contain token or email or both" do
      resp1 = Account.get_organisation_and_role_from_token(%{"token" => nil})
      resp2 = Account.get_organisation_and_role_from_token(%{"email" => nil})
      resp3 = Account.get_organisation_and_role_from_token(%{})
      assert resp1 == nil
      assert resp2 == nil
      assert resp3 == nil
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
      assert found_user == {:error, :invalid_email}
    end

    test "return error when invalid data is provided" do
      found_user = Account.find(123)
      assert found_user == {:error, :invalid_email}
    end
  end

  @tag :authenticate
  describe "authenticate/1" do
    test "successfully authenticate when correct password is given" do
      user = insert(:user_with_personal_organisation)
      current_org_id = user.current_org_id
      user_email = user.email

      %{tokens: [access_token: access_token, refresh_token: refresh_token], user: _updated_user} =
        Account.authenticate(%{user: user, password: "encrypt"})

      {_, _, access_token_resource} = Guardian.resource_from_token(access_token)
      {_, _, refresh_token_resource} = Guardian.resource_from_token(refresh_token)

      assert refresh_token_resource["exp"] >= access_token_resource["exp"]

      assert %{"organisation_id" => ^current_org_id, "sub" => ^user_email, "typ" => "access"} =
               access_token_resource

      assert %{"organisation_id" => ^current_org_id, "sub" => ^user_email, "typ" => "refresh"} =
               refresh_token_resource

      assert user.roles
      assert user.current_org_id == current_org_id
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

  describe "refresh_token_exchange/2" do
    test "returns access token and refresh token valid tokens" do
      user = insert(:user_with_personal_organisation)

      %{tokens: [access_token: access_token, refresh_token: refresh_token]} =
        Account.authenticate(%{user: user, password: "encrypt"})

      {_, _, access_token_resource} = Guardian.resource_from_token(access_token)
      {_, _, refresh_token_resource} = Guardian.resource_from_token(refresh_token)

      access_token_resource_org_id = access_token_resource["organisation_id"]
      access_token_resource_sub = access_token_resource["sub"]
      access_token_resource_typ = access_token_resource["typ"]

      refresh_token_resource_org_id = refresh_token_resource["organisation_id"]
      refresh_token_resource_sub = refresh_token_resource["sub"]
      refresh_token_resource_typ = refresh_token_resource["typ"]

      {:ok, access_token: new_access_token, refresh_token: new_refresh_token} =
        WraftDoc.Account.refresh_token_exchange(refresh_token)

      {_, _, new_access_token_resource} = Guardian.resource_from_token(new_access_token)
      {_, _, new_refresh_token_resource} = Guardian.resource_from_token(new_refresh_token)

      refute access_token_resource["jti"] == new_access_token_resource["jti"]
      refute refresh_token_resource["jti"] == new_refresh_token_resource["jti"]
      assert new_refresh_token_resource["exp"] >= new_access_token_resource["exp"]

      assert %{
               "organisation_id" => ^access_token_resource_org_id,
               "sub" => ^access_token_resource_sub,
               "typ" => ^access_token_resource_typ
             } = new_access_token_resource

      assert %{
               "organisation_id" => ^refresh_token_resource_org_id,
               "sub" => ^refresh_token_resource_sub,
               "typ" => ^refresh_token_resource_typ
             } = new_refresh_token_resource
    end

    test "returns error for valid but revoked refresh token" do
      user = insert(:user_with_personal_organisation)

      %{tokens: [access_token: _access_token, refresh_token: refresh_token]} =
        Account.authenticate(%{user: user, password: "encrypt"})

      Guardian.revoke(refresh_token)

      assert {:error, :token_not_found} ==
               WraftDoc.Account.refresh_token_exchange(refresh_token)
    end

    test "return error for invalid tokens" do
      assert {:error, :invalid_token} ==
               WraftDoc.Account.refresh_token_exchange("invalid_token")
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

    test "return error on updating profile pic with a file greater than 1 MB" do
      profile = insert(:profile, gender: "Female", dob: "1998-04-01")

      profile_pic = %Plug.Upload{
        content_type: "image/jpg",
        path: File.cwd!() <> "/priv/static/images/over_limit_sized_image.jpg",
        filename: "over_limit_sized_image.jpg"
      }

      params = %{name: "new name", dob: "1990-01-22", gender: "Male", profile_pic: profile_pic}

      {:error, changeset} = Account.update_profile(profile.user, params)

      assert %{profile_pic: ["is invalid"]} == errors_on(changeset)
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

  describe "get_user_by_email/1" do
    test "gets user with valid email" do
      %{id: user_id, email: email} = insert(:user)
      response = Account.get_user_by_email(email)

      assert %User{id: ^user_id, email: ^email} = response
    end

    test "return nil when non-existent email is given" do
      assert nil == Account.get_user_by_email("error404notfound@gmail.com")
    end

    test "return nil with invalid params" do
      assert nil == Account.get_user_by_email(1)
    end
  end

  describe "send_email/2" do
    test "creates email background job for valid email and token" do
      token =
        WraftDoc.create_phx_token("organisation_invite", %{
          email: @email
        })

      auth_token = insert(:auth_token, value: token, token_type: "email_verify")

      {:ok, job} = Account.send_email(@email, auth_token)

      assert job.args == %{
               email: @email,
               token: token
             }

      assert_enqueued(
        worker: EmailWorker,
        args: %{email: job.args.email, token: job.args.token},
        queue: :mailer
      )
    end
  end

  describe "send_password_reset_mail/1" do
    test "creates email background job for valid token" do
      auth_token = insert(:auth_token, token_type: "password_verify")

      {:ok, job} = Account.send_password_reset_mail(auth_token)

      assert job.args == %{email: auth_token.user.email, name: "wrafts user", token: "token"}

      assert_enqueued(
        worker: EmailWorker,
        args: %{email: job.args.email, token: job.args.token, name: job.args.name},
        queue: :mailer
      )
    end
  end

  describe "reset_password/1" do
    test "update user password when valid token and password are given" do
      user = insert(:user)
      auth_token = AuthTokens.create_password_token(%{"email" => user.email})
      params = %{"token" => auth_token.value, "password" => "newpassword"}
      updated_user = Account.reset_password(params)
      assert Bcrypt.verify_pass("newpassword", updated_user.encrypted_password) == true
    end

    test "does not update user password when password is not valid" do
      user = insert(:user)
      auth_token = AuthTokens.create_password_token(%{"email" => user.email})
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
