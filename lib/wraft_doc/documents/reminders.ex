defmodule WraftDoc.Documents.Reminders do
  @moduledoc """
  Context module for managing document reminders.
  """

  import Ecto
  import Ecto.Query
  require Logger

  alias WraftDoc.Account.User
  alias WraftDoc.Documents.Instance
  alias WraftDoc.Documents.Reminder
  alias WraftDoc.Repo

  @doc """
  List all reminders for a contract
  """
  @spec list_reminders(Instance.t()) :: [Reminder.t()] | []
  def list_reminders(%Instance{id: content_id}) do
    Reminder
    |> where([r], r.content_id == ^content_id)
    |> order_by([r], asc: r.reminder_date)
    |> Repo.all()
  end

  @doc """
  Get a specific reminder
  """
  @spec get_reminder(Instance.t(), Ecto.UUID.t()) :: Reminder.t() | nil
  def get_reminder(%Instance{id: content_id}, <<_::288>> = reminder_id),
    do: Repo.get_by(Reminder, id: reminder_id, content_id: content_id)

  def get_reminder(_, _), do: nil

  @doc """
  Add a new reminder for a contract
  """
  @spec add_reminder(User.t(), Instance.t(), map()) ::
          {:ok, Reminder.t()} | {:error, Ecto.Changeset.t()}
  def add_reminder(%User{} = current_user, %Instance{} = content, params) do
    current_user
    |> build_assoc(:reminders, content: content)
    |> Reminder.changeset(params)
    |> Repo.insert()
  end

  @doc """
  Updates an existing reminder for a contract
  """
  @spec update_reminder(Reminder.t(), map()) :: {:ok, Reminder.t()} | {:error, Ecto.Changeset.t()}
  def update_reminder(%Reminder{} = reminder, params) do
    reminder
    |> Reminder.changeset(params)
    |> Repo.update()
  end

  @doc """
  Delete a reminder
  """
  @spec delete_reminder(Reminder.t()) :: {:ok, Reminder.t()} | {:error, Ecto.Changeset.t()}
  def delete_reminder(reminder), do: Repo.delete(reminder)
end
