defmodule WraftDoc.Workers.EmailWorkerTest do
  @moduledoc """
  Tests for Oban worker for sending emails.
  """
  use WraftDoc.DataCase, async: true
  import ExUnit.CaptureLog
  require Logger

  alias WraftDoc.Workers.EmailWorker

  @email "temp@email.com"

  setup do
    Logger.configure(level: :info)
  end

  describe "performs sending email" do
    test "email verification mailer job" do
      token =
        WraftDoc.create_phx_token("email_verify", %{
          email: @email
        })

      {result, log} =
        with_log(fn ->
          perform_job(EmailWorker, %{"email" => @email, "token" => token})
        end)

      assert :ok == result
      assert String.contains?(log, "Email verification mailer job started...!") == true
      assert String.contains?(log, "Email verification mailer job end...!") == true
    end

    test "notification mailer job" do
      {result, log} =
        with_log(fn ->
          perform_job(EmailWorker, %{
            "email" => @email,
            "user_name" => "user_name",
            "notification_message" => "notification_message"
          })
        end)

      assert :ok == result
      assert String.contains?(log, "Notification mailer job started...!") == true
      assert String.contains?(log, "Notification mailer job end...!") == true
    end

    test "organisation mailer invite job" do
      organisation = insert(:organisation)

      token =
        WraftDoc.create_phx_token("organisation_invite", %{
          organisation_id: organisation.id,
          email: @email,
          role: "user"
        })

      {result, log} =
        with_log(fn ->
          perform_job(EmailWorker, %{
            "org_name" => organisation.name,
            "user_name" => "user_name",
            "email" => @email,
            "token" => token
          })
        end)

      assert :ok == result
      assert String.contains?(log, "Organisation invite mailer job started...!") == true
      assert String.contains?(log, "Organisation invite mailer job end...!") == true
    end

    test "password reset mailer invite job" do
      auth_token = insert(:auth_token, token_type: "password_verify")

      {result, log} =
        with_log(fn ->
          perform_job(EmailWorker, %{
            "name" => auth_token.user.name,
            "email" => auth_token.user.email,
            "token" => auth_token.value
          })
        end)

      assert :ok == result
      assert String.contains?(log, "Password reset mailer job started") == true
      assert String.contains?(log, "Password reset mailer job end") == true
    end
  end
end
