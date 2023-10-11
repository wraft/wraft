defmodule WraftDoc.Workers.EmailWorker do
  @moduledoc """
  Oban worker for sending emails.
  """
  use Oban.Worker, queue: :mailer
  require Logger
  alias WraftDocWeb.Mailer
  alias WraftDocWeb.Mailer.Email

  @impl Oban.Worker
  def perform(%Job{
        args: %{
          "org_name" => org_name,
          "user_name" => user_name,
          "email" => email,
          "token" => token
        }
      }) do
    Logger.info("Organisation invite mailer job started.")

    org_name
    |> Email.invite_email(user_name, email, token)
    |> Mailer.deliver()

    Logger.info("Organisation invite mailer job end.")
  end

  def perform(%Job{
        args: %{
          "user_name" => user_name,
          "notification_message" => notification_message,
          "email" => email
        }
      }) do
    Logger.info("Notification mailer job started.")

    user_name
    |> Email.notification_email(notification_message, email)
    |> Mailer.deliver()

    Logger.info("Notification mailer job end.")
  end

  def perform(%Job{
        args: %{
          "name" => name,
          "email" => email,
          "token" => token
        },
        tags: ["set_password"]
      }) do
    Logger.info("First time password set mailer job started.")

    name
    |> Email.password_set(email, token)
    |> Mailer.deliver()

    Logger.info("First time password set mailer job end.")
  end

  def perform(%Job{
        args: %{
          "name" => name,
          "email" => email,
          "token" => token
        }
      }) do
    Logger.info("Password reset mailer job started.")

    name
    |> Email.password_reset(token, email)
    |> Mailer.deliver()

    Logger.info("Password reset mailer job end.")
  end

  def perform(%Job{
        args: %{
          "token" => token,
          "email" => email
        }
      }) do
    Logger.info("Email verification mailer job started.")

    email
    |> Email.email_verification(token)
    |> Mailer.deliver()

    Logger.info("Email verification mailer job end.")
  end

  def perform(%Job{
        args: %{
          "name" => name,
          "email" => email
        },
        tags: ["waiting_list_acceptance"]
      }) do
    Logger.info("Waiting list acceptance mailer job started.")

    email
    |> Email.waiting_list_approved(name)
    |> Mailer.deliver()

    Logger.info("Waiting list acceptance mailer job end.")
  end

  def perform(%Job{
        args: %{
          "name" => name,
          "email" => email
        },
        tags: ["waiting_list_join"]
      }) do
    Logger.info("Waiting list join mailer job started.")

    email
    |> Email.waiting_list_join(name)
    |> Mailer.deliver()

    Logger.info("Waiting list join mailer job end.")
  end
end
