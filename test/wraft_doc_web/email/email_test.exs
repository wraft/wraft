defmodule WraftDocWeb.Email.EmailTest do
  @moduledoc """
  Test to ensure the correct delivery of the email
  """
  use WraftDoc.DataCase, async: true
  import Swoosh.TestAssertions

  alias Swoosh.Adapters.Test
  alias WraftDocWeb.Mailer.Email

  @test_email "test@email.com"
  @sender_email "no-reply@#{System.get_env("WRAFT_HOSTNAME")}"
  @token "token"
  @name "Sample Name"

  describe "send email on organisation invite" do
    test "return email sent if mail delivered" do
      user_name = "User_name"
      org_name = "org_name"
      token = "token"
      test_email = "test@email.com"

      email = Email.invite_email(org_name, user_name, test_email, token)

      {:ok, _} = Test.deliver(email, [])

      html_content =
        email.html_body
        |> Floki.parse_document!()
        |> Floki.text()
        |> String.replace(~r/\s+/, " ")
        |> String.trim()

      expected_content = [
        "Join #{org_name} on Wraft",
        "Hi #{user_name},",
        "#{user_name} has invited you to join #{org_name} in Wraft."
      ]

      Enum.each(expected_content, fn content ->
        assert String.contains?(html_content, content),
               "Expected to find '#{content}' in email body"
      end)

      assert email.to == [{"", test_email}]
      assert email.from == {"Wraft", "no-reply@wraft.app"}
      assert email.subject == "Invitation to join #{org_name} in Wraft"
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
      assert email.from == {"Wraft", @sender_email}
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
    test " return email sent if mail delivered" do
      email = Email.email_verification(@test_email, @token)

      Test.deliver(email, [])

      assert_email_sent()
      assert email.from == {"Wraft", @sender_email}
      assert email.subject == "Wraft - Verify your email"
      assert elem(List.last(email.to), 1) == @test_email

      html_content =
        email.html_body
        |> Floki.parse_document!()
        |> Floki.text()
        |> String.replace(~r/\s+/, " ")
        |> String.trim()

      expected_content = [
        "Verify Your Email Address",
        "/users/join_invite/verify_email/#{@token}"
      ]

      Enum.each(expected_content, fn content ->
        assert String.contains?(html_content, content),
               "Expected to find '#{content}' in email body"
      end)
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

      html_content =
        email.html_body
        |> Floki.parse_document!()
        |> Floki.text()
        |> String.replace(~r/\s+/, " ")
        |> String.trim()

      expected_content = [
        "Verify Your Email Address",
        "/users/join_invite/verify_email/#{@token}"
      ]

      Enum.each(expected_content, fn content ->
        assert String.contains?(html_content, content),
               "Expected to find '#{content}' in email body"
      end)
    end

    test "return email not send if not delivered" do
      Email.email_verification(@test_email, @token)

      refute_email_sent()
    end
  end

  describe "send email on waiting list approval" do
    test "return email sent if mail delivered" do
      registration_url =
        URI.encode("#{System.get_env("FRONTEND_URL")}/users/login/set_password?token=#{@token}")

      email = Email.waiting_list_approved(@test_email, @name, @token)
      Test.deliver(email, [])

      assert_email_sent()
      assert email.from == {"Wraft", @sender_email}
      assert email.subject == "Welcome to Wraft!"
      assert elem(List.last(email.to), 1) == @test_email
      assert email.html_body =~ "#{registration_url}"
      assert email.html_body =~ "Click here to continue"
    end

    test "return email not send if not delivered" do
      Email.waiting_list_approved(@test_email, @name, "token")

      refute_email_sent()
    end
  end

  describe "send email on joining waiting list" do
    test "return email sent if mail delivered" do
      email = Email.waiting_list_join(@test_email, @name)
      Test.deliver(email, [])

      assert_email_sent()
      assert email.from == {"Wraft", @sender_email}
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

  describe "send email on organisation delete code" do
    test "return email sent if mail delivered" do
      email = Email.organisation_delete_code(@test_email, "code", @name, "org_name")
      Test.deliver(email, [])

      assert_email_sent()
      assert email.from == {"Wraft", @sender_email}
      assert email.subject == "Wraft - Delete Organisation"
      assert elem(List.last(email.to), 1) == @test_email

      assert email.html_body =~
               "If you did not request this deletion, you can ignore this email and your organization will not be deleted."
    end

    test "return email not send if not delivered" do
      Email.organisation_delete_code(@test_email, "code", @name, "org_name")

      refute_email_sent()
    end
  end
end
