defmodule WraftDocWeb.Mailer.Email do
  @moduledoc false

  import Swoosh.Email

  def invite_email(org_name, user_name, email, token) do
    new()
    |> to(email)
    |> from({"WraftDoc", "admin@wraftdocs.com"})
    |> subject("Invitation to join #{org_name} in WraftDocs")
    |> html_body(
      "Hi, #{user_name} has invited you to join #{org_name} in WraftDocs. \n
      Click <a href=#{System.get_env("WRAFT_URL")}/users/signup?token=#{token}>here</a> below to join."
    )
  end

  def notification_email(user_name, notification_message, email) do
    new()
    |> to(email)
    |> from({"WraftDoc", "admin@wraftdocs.com"})
    |> subject(" #{user_name} ")
    |> html_body("Hi, #{user_name} #{notification_message}")
  end

  @doc """
  Password reset link.
  """
  def password_reset(name, token, email) do
    new()
    |> to(email)
    |> from({"WraftDoc", "admin@wraftdocs.com"})
    |> subject("Forgot your WraftDoc Password?")
    |> html_body(
      "Hi #{name}.\n You recently requested to reset your password for WraftDocs
    Click <a href=#{System.get_env("WRAFT_URL")}/users/password/reset?token=#{token}>here</a> to reset"
    )
  end

  @doc """
    User account verification
  """
  def email_verification(email, token) do
    new()
    |> to(email)
    |> from({"WraftDoc", "admin@wraftdocs.com"})
    |> subject("Wraft - Verify your email")
    |> html_body(
      "
      <h1>Verify your email address<h1>
      <h3>To continue setting up your Wraft account, please verify that this is your email address.<h3>
      Click <a href=#{System.get_env("WRAFT_URL")}/user/verify_email_token/#{token}>Verify email address</a>"
    )
  end

  @doc """
    Waiting list approved
  """
  def waiting_list_approved(email, name) do
    registration_url =
      URI.encode("#{System.get_env("WRAFT_URL")}/users/signup?email=#{email}&name=#{name}")

    new()
    |> to(email)
    |> from({"WraftDoc", "admin@wraftdocs.com"})
    |> subject("Welcome to Wraft!")
    |> html_body("""
    <body>
    <p>Hello #{name},</p>
    <p>We are excited to inform you that your application to join Wraft has been approved! Congratulations, and welcome aboard!</p>
    <p>You are now part of our exclusive community of users who will have access to our document automation tool. Please click the button below to continue.</p>
    <a href=#{registration_url}><button style="background-color: blue; color: white; border: none; padding: 10px 15px; border-radius: 5px;">Click here to continue</button></a>
    <p>If you have any questions or concerns, please don't hesitate to reach out to our support team.</p>
    <p>Thank you for choosing Wraft. We look forward to serving you!</p>
    <p>Best regards,</p>
    <p>Wraft Admin</p>
    """)
  end

  @doc """
    Waiting list join
  """
  def waiting_list_join(email, name) do
    new()
    |> to(email)
    |> from({"WraftDoc", "admin@wraftdocs.com"})
    |> subject("Thanks for showing interest in Wraft!")
    |> html_body("""
    <p>Hello #{name},</p>
    <p>Thank you for signing up to join Wraft's waiting list! We appreciate your interest in our document automation tool.</p>
    <p>We are currently onboarding our existing customers, but we will keep you updated on your waiting list status. We expect to grant you access shortly.</p>
    <p>If you have any questions or concerns, please don't hesitate to reach out to our support team.</p>
    <p>Best regards,</p>
    <p>Wraft Admin</p>
    """)
  end
end
