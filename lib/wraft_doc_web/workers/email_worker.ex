defmodule WraftDocWeb.Worker.EmailWorker do
  @moduledoc """
  Oban worker for sending emails.
  """
  use Oban.Worker, queue: :mailer
  @impl Oban.Worker
  alias WraftDocWeb.{Mailer, Mailer.Email}

  def perform(
        %{"org_name" => org_name, "user_name" => user_name, "email" => email, "token" => token},
        _job
      ) do
    IO.puts("Job started..!")
    org_name |> Email.invite_email(user_name, email, token) |> Mailer.deliver_later()
    IO.puts("Job finished..!")

    :ok
  end
end
