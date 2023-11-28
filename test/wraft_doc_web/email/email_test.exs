defmodule WraftDocWeb.Email.EmailTest do
  @moduledoc """
  Test to ensure the correct delivery of the email
  """
  use WraftDoc.DataCase, async: true
  import Swoosh.TestAssertions

  alias Swoosh.Adapters.Test
  alias WraftDocWeb.Mailer.Email

  @test_email "test@email.com"
  @token "token"
  @name "Sample Name"

  describe "send email on organisation invite" do
    test "return email sent if mail delivered" do
      org_name = "org_name"
      user_name = "user_name"

      email = Email.invite_email(org_name, user_name, @test_email, @token)

      Test.deliver(email, [])

      assert_email_sent()
      assert email.from == {"WraftDoc", "admin@wraftdocs.com"}
      assert email.subject == "Invitation to join #{org_name} in WraftDocs"
      assert elem(List.last(email.to), 1) == @test_email

      assert email.html_body ==
               "Hi, #{user_name} has invited you to join #{org_name} in WraftDocs. \n
      Click <a href=#{System.get_env("WRAFT_URL")}/users/signup?token=#{@token}>here</a> below to join."
    end

    test "return email not send if not delivered" do
      org_name = "org_name"
      user_name = "user_name"

      Email.invite_email(org_name, user_name, @test_email, @token)
      refute_email_sent()
    end
  end

  describe "send email on notification message" do
    test "return email sent if mail delivered" do
      user_name = "user_name"
      notification_message = "notification_message"

      email = Email.notification_email(user_name, notification_message, @test_email)

      Test.deliver(email, [])

      assert_email_sent()
      assert email.from == {"WraftDoc", "admin@wraftdocs.com"}
      assert email.subject == " #{user_name} "
      assert elem(List.last(email.to), 1) == @test_email
      assert email.html_body == "Hi, #{user_name} #{notification_message}"
    end

    test "return email not send if not delivered" do
      user_name = "user_name"
      notification_message = "notification_message"

      Email.notification_email(user_name, notification_message, @test_email)

      refute_email_sent()
    end
  end

  describe "send email on password reset link" do
    test "return email sent if mail delivered" do
      auth_token = insert(:auth_token, value: @token, token_type: "password_verify")

      email = Email.password_reset(auth_token.user.name, @token, auth_token.user.email)

      Test.deliver(email, [])

      assert_email_sent()
      assert email.from == {"WraftDoc", "admin@wraftdocs.com"}
      assert email.subject == "Forgot your WraftDoc Password?"
      assert elem(List.last(email.to), 1) == auth_token.user.email

      assert email.html_body ==
               "Hi #{auth_token.user.name}.\n You recently requested to reset your password for WraftDocs
    Click <a href=#{System.get_env("WRAFT_URL")}/users/password/reset?token=#{@token}>here</a> to reset"
    end

    test "return email not send if not delivered" do
      auth_token = insert(:auth_token, value: @token, token_type: "password_verify")

      Email.password_reset(auth_token.user.name, @token, auth_token.user.email)

      refute_email_sent()
    end
  end

  describe "send email on user account verification" do
    test "return email sent if mail delivered" do
      email = Email.email_verification(@test_email, @token)

      Test.deliver(email, [])

      assert_email_sent()
      assert email.from == {"WraftDoc", "admin@wraftdocs.com"}
      assert email.subject == "Wraft - Verify your email"
      assert elem(List.last(email.to), 1) == @test_email

      assert email.html_body ==
               "
      <h1>Verify your email address<h1>
      <h3>To continue setting up your Wraft account, please verify that this is your email address.<h3>
      Click <a href=#{System.get_env("WRAFT_URL")}/user/verify_email_token/#{@token}>Verify email address</a>"
    end

    test "return email not send if not delivered" do
      Email.email_verification(@test_email, @token)

      refute_email_sent()
    end
  end

  describe "send email on waiting list approval" do
    test "return email sent if mail delivered" do
      registration_url =
        URI.encode(
          "#{System.get_env("WRAFT_URL")}/users/signup?email=#{@test_email}&name=#{@name}"
        )

      email = Email.waiting_list_approved(@test_email, @name, "token")
      Test.deliver(email, [])

      assert_email_sent()
      assert email.from == {"WraftDoc", "admin@wraftdocs.com"}
      assert email.subject == "Welcome to Wraft!"
      assert elem(List.last(email.to), 1) == @test_email
      assert email.html_body =~ "#{registration_url}"
      assert email.html_body =~ "Click here to continue"
    end

    test "return email not send if not delivered" do
      Email.waiting_list_approved(@test_email, @name)

      refute_email_sent()
    end
  end

  describe "send email on joining waiting list" do
    test "return email sent if mail delivered" do
      email = Email.waiting_list_join(@test_email, @name)
      Test.deliver(email, [])

      assert_email_sent()
      assert email.from == {"WraftDoc", "admin@wraftdocs.com"}
      assert email.subject == "Thanks for showing interest in Wraft!"
      assert elem(List.last(email.to), 1) == @test_email

      assert email.html_body =~
               "Thank you for signing up to join Wraft's waiting list! We appreciate your interest in our document automation tool"
    end

    test "return email not send if not delivered" do
      Email.waiting_list_join(@test_email, @name)

      refute_email_sent()
    end
  end
end
