defmodule WraftDocWeb.Worker.EmailWorker do
  @moduledoc """
  Oban worker for sending emails.
  """
  use Oban.Worker, queue: :mailer
  alias WraftDocWeb.{Mailer, Mailer.Email}

  @impl Oban.Worker
  def perform(%Job{
        args: %{
          "org_name" => org_name,
          "user_name" => user_name,
          "email" => email,
          "token" => token
        }
      }) do
    IO.puts("Job started..!")

    org_name
    |> Email.invite_email(user_name, email, token)
    |> Mailer.deliver_later()

    IO.puts("Job finished..!")

    :ok
  end

  def perform(%Job{
        args: %{
          "user_name" => user_name,
          "notification_message" => notification_message,
          "email" => email
        }
      }) do
    IO.puts("Notification mail job started...!")

    user_name
    |> Email.notification_email(notification_message, email)
    |> Mailer.deliver_later()

    IO.puts("Notification mailer job end...!")
  end
end
