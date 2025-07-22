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
        },
        tags: ["waiting_list_acceptance"]
      }) do
    Logger.info("Waiting list acceptance mailer job started.")

    email
    |> Email.waiting_list_approved(name, token)
    |> Mailer.deliver()

    Logger.info("Waiting list acceptance mailer job end.")
  end

  def perform(%Job{
        args: %{
          "email" => email,
          "instance_id" => instance_id,
          "signer_name" => signer_name
        },
        tags: ["notify_document_owner_signature_complete"]
      }) do
    Logger.info("Notify document owner signature complete mailer job started.")

    email
    |> Email.signature_completed_email(instance_id, signer_name)
    |> Mailer.deliver()

    Logger.info("Notify document owner signature complete mailer job end.")
  end

  def perform(%Job{
        args: %{
          "email" => email,
          "instance_id" => instance_id,
          "signer_name" => name,
          "signed_document" => signed_document,
          "document_name" => document_name
        },
        tags: ["document_fully_signed"]
      }) do
    Logger.info("Document fully signed mailer job started.")

    email
    |> Email.document_fully_signed_email(instance_id, name, signed_document, document_name)
    |> Mailer.deliver()

    Logger.info("Document fully signed mailer job end.")
  end

  def perform(%Job{
        args: %{
          "name" => name,
          "email" => email,
          "token" => token,
          "document_id" => document_id,
          "instance_id" => instance_id
        },
        tags: ["document_signature_request"]
      }) do
    Logger.info("Document signature request mailer job started.")

    email
    |> Email.signature_request_email(name, instance_id, document_id, token)
    |> Mailer.deliver()

    Logger.info("Document signature request mailer job end.")
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
          "email" => email,
          "delete_code" => delete_code,
          "user_name" => user_name,
          "organisation_name" => organisation_name
        },
        tags: ["organisation_delete_code"]
      }) do
    Logger.info("Organisation delete code mailer job started.")

    email
    |> Email.organisation_delete_code(delete_code, user_name, organisation_name)
    |> Mailer.deliver()

    Logger.info("Organisation delete code mailer job end.")
  end

  def perform(%Job{
        args: %{
          "email" => email,
          "token" => token,
          "instance_id" => instance_id,
          "document_id" => document_id
        },
        tags: ["document_instance_share"]
      }) do
    Logger.info("Document instance share mailer job started.")

    email
    |> Email.document_instance_share(token, instance_id, document_id)
    |> Mailer.deliver()

    Logger.info("Document  instance share mailer job end.")
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
        tags: ["waiting_list_join"]
      }) do
    Logger.info("Waiting list join mailer job started.")

    email
    |> Email.waiting_list_join(name)
    |> Mailer.deliver()

    Logger.info("Waiting list join mailer job end.")
  end

  def perform(%Job{
        args: %{
          "user_name" => name,
          "email" => email,
          "document_title" => document_title,
          "instance_id" => instance_id,
          "document_id" => document_id
        },
        tags: ["document_reminder"]
      }) do
    Logger.info("Document reminder mailer job started.")

    email
    |> Email.document_reminder(name, document_title, instance_id, document_id)
    |> Mailer.deliver()

    Logger.info("Document reminder mailer job end.")
  end

  def perform(%Job{
        args: %{
          "template" => template,
          "subject" => subject,
          "params" => params
        },
        tags: ["notification"]
      }) do
    template
    |> String.to_existing_atom()
    |> Email.notification_email(subject, atomize_keys(params))
    |> Mailer.deliver()
  end

  defp atomize_keys(map) do
    for {k, v} <- map, into: %{} do
      {String.to_atom(k), v}
    end
  end
end
