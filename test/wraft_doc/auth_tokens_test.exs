defmodule WraftDoc.AuthTokensTest do
  @moduledoc false
  use WraftDoc.DataCase, async: true

  alias WraftDoc.AuthTokens
  alias WraftDoc.AuthTokens.AuthToken

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
end
