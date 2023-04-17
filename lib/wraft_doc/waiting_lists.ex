defmodule WraftDoc.WaitingLists do
  @moduledoc """
  Module that handles the repo connections of the waiting list context.
  """

  alias WraftDoc.Repo
  alias WraftDoc.WaitingLists.WaitingList
  alias WraftDoc.Workers.EmailWorker

  @doc """
   Add user to waiting list
  """
  @spec join_waiting_list(map()) :: {:ok, WaitingList.t()} | {:error, Ecto.Changeset.t()}
  def join_waiting_list(params) do
    %WaitingList{}
    |> WaitingList.changeset(params)
    |> Repo.insert()
  end

  # TODO move all mail related functions to a different module
  @doc """
    Waiting list confirmation email
  """
  @spec waitlist_confirmation_email(WaitingList.t()) ::
          {:ok, Oban.Job.t()} | {:error, Oban.Job.changeset() | term()}
  def waitlist_confirmation_email(waiting_list) do
    user_name = "#{waiting_list.first_name} #{waiting_list.last_name}"

    %{user_name: user_name, email: waiting_list.email}
    |> EmailWorker.new(queue: "mailer", tags: ["waiting_list_join"])
    |> Oban.insert()
  end
end
