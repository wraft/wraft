defmodule WraftDoc.AuthTokensTest do
  @moduledoc false
  use WraftDoc.DataCase, async: true

  alias WraftDoc.AuthTokens
  alias WraftDoc.AuthTokens.AuthToken
  alias WraftDoc.Workers.EmailWorker

  describe "insert_auth_token!/2" do
    test "inserts new auth token with valid params" do
      user = insert(:user)
      params = %{value: "value", token_type: "invite"}
      assert %AuthToken{} = auth_token = AuthTokens.insert_auth_token!(user, params)
      assert [^auth_token] = Repo.all(AuthToken)
    end

    test "raises with invalid params" do
      user = insert(:user)
      params = %{value: "value", token_type: "wrong"}

      assert_raise(Ecto.InvalidChangesetError, fn ->
        AuthTokens.insert_auth_token!(user, params)
      end)
    end

    test "raises with invalid arguments" do
      params = %{value: "value", token_type: "invite"}

      assert_raise(RuntimeError, "Unexpected arguments passed.", fn ->
        AuthTokens.insert_auth_token!("invalid", params)
      end)
    end
  end

  describe "create_password_token/1" do
    # FIXME
    test "create token when the email of a valid user is given" do
      user = insert(:user)
      token = AuthTokens.create_password_token(%{"email" => user.email})
      assert token.value != nil
      assert token.user.email == user.email
      assert token.token_type == :password_verify
    end

    test "return error when the email given is not of valid user" do
      response = AuthTokens.create_password_token(%{"email" => "testamail@xyz.com"})
      assert response == {:error, :invalid_email}
    end

    test "return error for invalid attrs" do
      response = AuthTokens.create_password_token(%{})
      assert response == {:error, :invalid_email}
    end
  end

  describe "delete_auth_token!/1" do
    test "deletes the given auth token" do
      auth_token = insert(:auth_token)
      deleted_auth_token = AuthTokens.delete_auth_token!(auth_token)

      assert auth_token.id == deleted_auth_token.id
      assert [] == Repo.all(AuthToken)
    end

    test "raises with non existing auth token" do
      auth_token = insert(:auth_token)
      assert AuthTokens.delete_auth_token!(auth_token)
      assert_raise(Ecto.StaleEntryError, fn -> AuthTokens.delete_auth_token!(auth_token) end)
    end

    test "raises with invalid auth token" do
      assert_raise(BadMapError, fn -> AuthTokens.delete_auth_token!("non-exitest-token") end)
    end
  end

  describe "delete_auth_token/1" do
    test "deletes the auth token with the given value" do
      auth_token = insert(:auth_token)
      {:ok, deleted_auth_token} = AuthTokens.delete_auth_token(auth_token.value)

      assert auth_token.id == deleted_auth_token.id
      assert [] == Repo.all(AuthToken)
    end

    test "returns {:error, :invalid}  with non-existent token value" do
      {:error, :invalid} = AuthTokens.delete_auth_token("non-exitest-token")
    end
  end

  describe "delete_auth_token/2" do
    test "deletes all auth tokens of given type belonging to the given user ID" do
      user = insert(:user)
      auth_token1 = insert(:auth_token, token_type: "password_verify", user: user)
      auth_token2 = insert(:auth_token, token_type: "password_verify", user: user)

      auth_token3 = insert(:auth_token, token_type: "invite", user: user)
      auth_token4 = insert(:auth_token)

      assert {2, nil} = AuthTokens.delete_auth_token(user.id, "password_verify")

      auth_token_ids = AuthToken |> Repo.all() |> Enum.map(& &1.id) |> Enum.sort()

      refute Enum.member?(auth_token_ids, auth_token1.id)
      refute Enum.member?(auth_token_ids, auth_token2.id)
      assert Enum.sort([auth_token3.id, auth_token4.id]) == auth_token_ids
    end
  end

  describe "create_token_and_send_email/2" do
    test "creates an email verification auth token with valid email" do
      user = insert(:user)
      AuthTokens.create_token_and_send_email(user.email)
      assert %AuthToken{} = Repo.get_by(AuthToken, token_type: "email_verify", user_id: user.id)
    end

    test "creates an oban job to send an email ID verification email with valid email" do
      %{email: email} = insert(:user)

      assert {:ok,
              %Oban.Job{
                worker: "WraftDoc.Workers.EmailWorker",
                args: %{email: ^email, token: _}
              }} = AuthTokens.create_token_and_send_email(email)
    end

    # FIXME
    test "returns {:error, :invalid_email} with invalid email" do
      assert {:error, :invalid_email} =
               AuthTokens.create_token_and_send_email("invalid@email.com")
    end
  end

  describe "create_email_verification_token/1" do
    test "create token when the email of a valid user is given" do
      user = insert(:user)
      {:ok, token} = AuthTokens.create_email_verification_token(user.email)

      {:ok, %{email: email}} = AuthTokens.check_token(token.value, :email_verify)

      assert user.email == email
      assert token.value != nil
      assert token.user_id == user.id
      assert token.token_type == :email_verify
    end

    test "return error when the email given is not of valid user" do
      response = AuthTokens.create_email_verification_token("testamail@xyz.com")
      assert response == {:error, :invalid_email}
    end

    test "return error for invalid attrs" do
      response = AuthTokens.create_email_verification_token("invalid email format")
      assert response == {:error, :invalid_email}
    end
  end

  describe "check_token/2" do
    test "test when valid token is given" do
      user = insert(:user)
      auth_token = AuthTokens.create_password_token(%{"email" => user.email})
      response = AuthTokens.check_token(auth_token.value, :password_verify)
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

      AuthTokens.insert_auth_token!(user, %{value: token, token_type: "invite"})

      assert {:ok, response} = AuthTokens.check_token(token, :invite)
      assert %{organisation_id: org_id, email: email} == response
    end

    test "test when invalid token is given" do
      value = WraftDoc.create_phx_token("invalid", "email")
      auth_token = insert(:auth_token, value: value, token_type: "password_verify")
      response = AuthTokens.check_token(auth_token.value, :password_verify)
      assert response == {:error, :fake}
    end

    test "test when expired token is given" do
      value = WraftDoc.create_phx_token("reset", "email", signed_at: -861)

      auth_token = insert(:auth_token, value: value, token_type: "password_verify")
      response = AuthTokens.check_token(auth_token.value, :password_verify)
      assert response == {:error, :expired}
    end

    test "test when token does not exist" do
      response = AuthTokens.check_token("invalid_token", :password_verify)
      assert response == {:error, :fake}
    end
  end

  describe "generate_delete_token_and_send_email/2" do
    test "generate delete token and send email" do
      user = insert(:user_with_organisation)
      organisation = List.first(user.owned_organisations)
      {:ok, job} = AuthTokens.generate_delete_token_and_send_email(user, organisation)

      [auth_token] = Repo.all(AuthToken)
      [_, delete_code] = String.split(auth_token.value, ":")

      assert job.args == %{
               email: user.email,
               organisation_name: organisation.name,
               user_name: user.name,
               delete_code: delete_code
             }

      assert_enqueued(
        worker: EmailWorker,
        tags: ["organisation_delete_code"],
        args: %{
          email: job.args.email,
          delete_code: job.args.delete_code,
          organisation_name: job.args.organisation_name,
          user_name: job.args.user_name
        },
        queue: :mailer
      )
    end

    test "two delete codes are not allowed to persist at the same time hence avoiding the possiblity for collision" do
      user = insert(:user_with_organisation)
      organisation = List.first(user.owned_organisations)

      # Adding an additional delete code.
      delete_code = 100_000..999_999 |> Enum.random() |> Integer.to_string()

      insert(:auth_token,
        value: "#{organisation.id}:#{delete_code}",
        token_type: "delete_organisation",
        user: user,
        expiry_datetime: NaiveDateTime.add(NaiveDateTime.utc_now(), 10 * 60, :second)
      )

      {:ok, job} = AuthTokens.generate_delete_token_and_send_email(user, organisation)

      # Only one delete code exist at any given point of time.
      # [auth_token] = Repo.all(AuthToken)
      [auth_token | _] =
        Repo.all(from(a in AuthToken, where: a.token_type == ^"delete_organisation"))

      assert job.args == %{
               email: user.email,
               organisation_name: organisation.name,
               user_name: user.name,
               delete_code: auth_token.value |> String.split(":") |> List.last()
             }

      assert_enqueued(
        worker: EmailWorker,
        tags: ["organisation_delete_code"],
        args: %{
          email: job.args.email,
          delete_code: job.args.delete_code,
          organisation_name: job.args.organisation_name,
          user_name: job.args.user_name
        },
        queue: :mailer
      )
    end

    test "return error for invalid input" do
      assert {:error, :fake} = AuthTokens.generate_delete_token_and_send_email(nil, nil)
    end
  end

  describe "verify_delete_token/2" do
    test "returns token on successful verification" do
      user = insert(:user_with_organisation)
      organisation = List.first(user.owned_organisations)
      insert(:user_organisation, user: user, organisation: organisation)

      delete_code = 100_000..999_999 |> Enum.random() |> Integer.to_string()

      insert(:auth_token,
        value: "#{organisation.id}:#{delete_code}",
        token_type: "delete_organisation",
        user: user,
        expiry_datetime: NaiveDateTime.add(NaiveDateTime.utc_now(), 10 * 60, :second)
      )

      auth_token = AuthTokens.verify_delete_token(user, %{"code" => delete_code})

      assert auth_token.value == "#{organisation.id}:#{delete_code}"
      assert auth_token.token_type == :delete_organisation
      assert auth_token.user_id == user.id
    end

    test "return error if the organisation is invalid" do
      user = insert(:user_with_organisation)
      organisation = List.first(user.owned_organisations)
      insert(:user_organisation, user: user, organisation: organisation)

      delete_code = 100_000..999_999 |> Enum.random() |> Integer.to_string()

      insert(:auth_token,
        value: "#{Ecto.UUID.generate()}:#{delete_code}",
        token_type: "delete_organisation",
        user: user,
        expiry_datetime: NaiveDateTime.add(NaiveDateTime.utc_now(), 10 * 60, :second)
      )

      assert {:error, :fake} == AuthTokens.verify_delete_token(user, %{"code" => delete_code})
    end

    test "returns error on expired token" do
      user = insert(:user_with_organisation)
      organisation = List.first(user.owned_organisations)
      insert(:user_organisation, user: user, organisation: organisation)

      delete_code = 100_000..999_999 |> Enum.random() |> Integer.to_string()

      insert(:auth_token,
        value: "#{organisation.id}:#{delete_code}",
        token_type: "delete_organisation",
        user: user,
        expiry_datetime: NaiveDateTime.add(NaiveDateTime.utc_now(), -1 * 60, :second)
      )

      assert {:error, :fake} == AuthTokens.verify_delete_token(user, %{"code" => delete_code})
    end

    test "return error for invalid token" do
      user = insert(:user_with_organisation)
      organisation = List.first(user.owned_organisations)
      insert(:user_organisation, user: user, organisation: organisation)
      assert {:error, :fake} = AuthTokens.verify_delete_token(%{"token" => "invalid"}, user)
    end

    test "return error for invalid input" do
      assert {:error, :fake} = AuthTokens.verify_delete_token(nil, nil)
    end
  end

  describe "get_auth_token/3" do
    test "returns the auth token when valid value and token type are given" do
      user = insert(:user_with_organisation)

      auth_token =
        insert(:auth_token,
          value: "value",
          token_type: "delete_organisation",
          user: user,
          expiry_datetime: NaiveDateTime.add(NaiveDateTime.utc_now(), 10 * 60, :second)
        )

      output_auth_token = AuthTokens.get_auth_token("value", :delete_organisation)

      assert output_auth_token.id == auth_token.id
      assert output_auth_token.value == auth_token.value
      assert output_auth_token.token_type == auth_token.token_type
      assert output_auth_token.user_id == auth_token.user_id
      assert output_auth_token.expiry_datetime == auth_token.expiry_datetime
    end

    test "returns the auth token when valid value and token type are given but expiry date time is not set" do
      user = insert(:user_with_organisation)

      auth_token =
        insert(:auth_token,
          value: "value",
          token_type: "password_verify",
          user: user
        )

      output_auth_token = AuthTokens.get_auth_token("value", :password_verify)

      assert output_auth_token.id == auth_token.id
      assert output_auth_token.value == auth_token.value
      assert output_auth_token.token_type == auth_token.token_type
      assert output_auth_token.user_id == auth_token.user_id
      assert output_auth_token.expiry_datetime == auth_token.expiry_datetime
    end

    test "returns the auth token when valid value, token type and user_id are given" do
      user = insert(:user_with_organisation)

      auth_token =
        insert(:auth_token,
          value: "value",
          token_type: "delete_organisation",
          user: user,
          expiry_datetime: NaiveDateTime.add(NaiveDateTime.utc_now(), 10 * 60, :second)
        )

      output_auth_token =
        AuthTokens.get_auth_token("value", :delete_organisation, %{"user_id" => user.id})

      assert output_auth_token.id == auth_token.id
      assert output_auth_token.value == auth_token.value
      assert output_auth_token.token_type == auth_token.token_type
      assert output_auth_token.user_id == auth_token.user_id
      assert output_auth_token.expiry_datetime == auth_token.expiry_datetime
    end

    test "returns the auth token when valid value, token type and invalid params are given" do
      user = insert(:user_with_organisation)

      auth_token =
        insert(:auth_token,
          value: "value",
          token_type: "delete_organisation",
          user: user,
          expiry_datetime: NaiveDateTime.add(NaiveDateTime.utc_now(), 10 * 60, :second)
        )

      output_auth_token =
        AuthTokens.get_auth_token("value", :delete_organisation, %{"invalid" => "invalid"})

      assert output_auth_token.id == auth_token.id
      assert output_auth_token.value == auth_token.value
      assert output_auth_token.token_type == auth_token.token_type
      assert output_auth_token.user_id == auth_token.user_id
      assert output_auth_token.expiry_datetime == auth_token.expiry_datetime
    end

    test "returns nil when expired token is given" do
      user = insert(:user_with_organisation)

      insert(:auth_token,
        value: "value",
        token_type: "delete_organisation",
        user: user,
        expiry_datetime: NaiveDateTime.add(NaiveDateTime.utc_now(), -10 * 60, :second)
      )

      assert nil ==
               AuthTokens.get_auth_token("value", :delete_organisation, %{"user_id" => user.id})
    end

    test "returns nil when token does not exist" do
      assert nil == AuthTokens.get_auth_token("invalid", :delete_organisation)
    end
  end
end
