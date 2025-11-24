defmodule WraftDoc.Workers.EmailWorkerTest do
  @moduledoc """
  Tests for Oban worker for sending emails.
  """
  use WraftDoc.DataCase, async: true
  import ExUnit.CaptureLog
  require Logger

  alias WraftDoc.Workers.EmailWorker

  @email "temp@email.com"
  @name "Sample Name"

  setup do
    Logger.configure(level: :info)
    on_exit(fn -> Logger.configure(level: :warn) end)
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
      assert log =~ "Email verification mailer job started."
      assert log =~ "Email verification mailer job end."
    end

    # FIXME Emailer not working
    @tag :skip
    test "notification mailer job" do
      {result, log} =
        with_log(fn ->
          perform_job(
            EmailWorker,
            %{
              # Use the correct function clause
              "template" => "notification",
              "subject" => "Test Subject",
              "params" => %{
                "user_name" => "user_name",
                "notification_message" => "notification_message",
                "email" => @email
              }
            },
            # Add the required tags
            tags: ["notification"]
          )
        end)

      assert :ok == result
      assert log =~ "Notification mailer job started."
      assert log =~ "Notification mailer job end."
    end

    test "organisation mailer invite job" do
      organisation = insert(:organisation)
      role = insert(:role, organisation: organisation)

      token =
        WraftDoc.create_phx_token("organisation_invite", %{
          organisation_id: organisation.id,
          email: @email,
          role: role.id
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
      assert log =~ "Organisation invite mailer job started."
      assert log =~ "Organisation invite mailer job end."
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
      assert log =~ "Password reset mailer job started"
      assert log =~ "Password reset mailer job end"
    end

    test "waiting list approval mailer job" do
      {result, log} =
        with_log(fn ->
          perform_job(EmailWorker, %{"name" => @name, "email" => @email, "token" => "token"},
            tags: ["waiting_list_acceptance"]
          )
        end)

      assert :ok == result
      assert log =~ "Waiting list acceptance mailer job started."
      assert log =~ "Waiting list acceptance mailer job end."
    end

    # FIXME
    test "waiting list join mailer job" do
      {result, log} =
        with_log(fn ->
          perform_job(EmailWorker, %{"name" => @name, "email" => @email},
            tags: ["waiting_list_join"]
          )
        end)

      assert :ok == result
      assert log =~ "Waiting list join mailer job started."
    end

    test "organisation delete code mailer job" do
      user = insert(:user_with_organisation)
      organisation = List.first(user.owned_organisations)

      delete_code = 100_000..999_999 |> Enum.random() |> Integer.to_string()

      {result, log} =
        with_log(fn ->
          perform_job(
            EmailWorker,
            %{
              "email" => @email,
              "delete_code" => delete_code,
              "user_name" => user.name,
              "organisation_name" => organisation.name
            },
            tags: ["organisation_delete_code"]
          )
        end)

      assert :ok == result
      assert log =~ "Organisation delete code mailer job started."
    end
  end
end
