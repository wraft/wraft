defmodule WraftDoc.Documents.Reminders do
  @moduledoc """
  Context module for managing document reminders.
  """

  import Ecto
  import Ecto.Query
  require Logger

  alias WraftDoc.Account
  alias WraftDoc.Account.User
  alias WraftDoc.Documents.Instance
  alias WraftDoc.Documents.Reminder
  alias WraftDoc.Notifications
  alias WraftDoc.Repo
  alias WraftDoc.Workers.EmailWorker

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

  @doc """
  Process scheduled reminders that are due
  This function is called by a scheduled job
  """
  @spec process_scheduled_reminders :: :ok
  def process_scheduled_reminders do
    # Get all pending reminders that are due today or earlier
    Reminder
    |> where(
      [r],
      r.status == :pending and r.reminder_date <= ^Date.utc_today() and is_nil(r.sent_at)
    )
    |> preload(:content)
    |> Repo.all()
    |> Enum.each(&process_reminder/1)
  end

  # Send notifications for a reminder
  defp process_reminder(reminder) do
    # Mark reminder as sent
    reminder
    |> Reminder.sent_changeset()
    |> Repo.update()
    |> case do
      {:ok, updated_reminder} ->
        # Send notifications
        send_reminder_notifications(updated_reminder)

        # Remove from Valkey if it was stored there
        # remove_from_valkey(updated_reminder.instance_id, updated_reminder.id)

        {:ok, updated_reminder}

      error ->
        Logger.error("Failed to mark reminder as sent: #{inspect(error)}")
        error
    end
  end

  defp send_reminder_notifications(%{notification_type: :both} = reminder) do
    reminder
    |> send_email_notification()
    |> send_in_app_notification()
  end

  defp send_reminder_notifications(%{notification_type: :email} = reminder),
    do: send_email_notification(reminder)

  defp send_reminder_notifications(%{notification_type: :in_app} = reminder),
    do: send_in_app_notification(reminder)

  defp send_reminder_notifications(%{notification_type: type} = _reminder),
    do: Logger.warning("Unknown notification type", type: type)

  defp send_email_notification(reminder) do
    reminder
    |> get_recipients()
    |> Enum.each(fn recipient ->
      %{
        user_name: recipient.name,
        notification_message: reminder.message,
        email: recipient.email
      }
      |> EmailWorker.new()
      |> Oban.insert()
    end)

    Logger.info("Email notifications scheduled for reminder #{reminder.id}")

    reminder
  end

  defp send_in_app_notification(
         %Reminder{message: message, content: %Instance{id: document_id, serialized: serialized}} =
           reminder
       ) do
    reminder
    |> get_recipients()
    |> Enum.map(& &1.id)
    |> Notifications.create_notification(%{
      type: :document_reminder,
      message: message,
      document_id: document_id,
      document_title: serialized["title"]
    })

    Logger.info("In-app notifications sent for reminder #{reminder.id}")

    reminder
  end

  defp get_recipients(%{recipients: recipients})
       when is_list(recipients) and length(recipients) > 0 do
    recipients
    |> Enum.map(&Account.get_user/1)
    |> Enum.reject(&is_nil/1)
  end

  # defp get_recipients(%{instance: %{user_id: user_id}, instance_id: instance_id}) do
  #   [user_id | Documents.get_collaborator_ids(instance_id)]
  #   |> Enum.uniq()
  #   |> Enum.map(&Account.get_user/1)
  #   |> Enum.reject(&is_nil/1)
  # end
end
