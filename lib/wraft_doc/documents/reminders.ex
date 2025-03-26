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
  def add_reminder(
        %User{} = current_user,
        %Instance{} = content,
        # Atleast one recipient is required
        %{"recipients" => [_ | _]} = params
      ) do
    current_user
    |> build_assoc(:reminders, content: content)
    |> Reminder.changeset(params)
    |> Repo.insert()
  end

  # Adds the document allowed users as default recipients if the recipients are not explicitly added
  def add_reminder(
        %User{} = current_user,
        %Instance{allowed_users: default_recipients} = content,
        params
      ) do
    current_user
    |> build_assoc(:reminders, content: content)
    |> Reminder.changeset(Map.merge(params, %{"recipients" => default_recipients}))
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
  A function to calculate reminder intervals for contract-type documents.

  ## Auto Reminder Calculation

  The reminder intervals are determined based on the total duration between the
  document's `completed_date` and `expiry_date`. The reminders are set strategically
  at different intervals depending on the time remaining:

  - If the total duration is **greater than 1 year**, reminders are set at:
    - 6 months before expiry
    - 3 months before expiry
    - 1 month before expiry
    - 1 week before expiry
    - 1 day before expiry

  - If the total duration is **greater than 6 months**, reminders are set at:
    - 3 months before expiry
    - 1 month before expiry
    - 2 weeks before expiry
    - 1 week before expiry
    - 1 day before expiry

  - If the total duration is **greater than 3 months**, reminders are set at:
    - 1 month before expiry
    - 2 weeks before expiry
    - 1 week before expiry
    - 3 days before expiry
    - 1 day before expiry

  - If the total duration is **less than 3 months**, reminders are set at:
    - Halfway through the remaining duration
    - 1 week before expiry
    - 3 days before expiry
    - 1 day before expiry

  Any reminder dates that fall in the past are filtered out automatically.
  """
  @spec calculate_reminders(Date.t(), Integer.t()) :: [Date.t()]
  def calculate_reminders(expiry_date, duration) when duration > 365,
    do: reminder_days([180, 90, 30, 7, 1], expiry_date)

  def calculate_reminders(expiry_date, duration) when duration > 180,
    do: reminder_days([90, 30, 14, 7, 1], expiry_date)

  def calculate_reminders(expiry_date, duration) when duration > 90,
    do: reminder_days([30, 14, 7, 3, 1], expiry_date)

  def calculate_reminders(expiry_date, duration) do
    half_duration = div(duration, 2)
    reminder_days([half_duration, 7, 3, 1], expiry_date)
  end

  defp reminder_days(days_list, expiry_date), do: Enum.map(days_list, &Date.add(expiry_date, -&1))

  @doc """
    Create auto reminder for a contract document
  """
  def maybe_create_auto_reminders(
        current_user,
        %Instance{
          meta: %{"type" => "contract", "expiry_date" => expiry_date},
          allowed_users: default_recipients,
          approval_status: true
        } = instance
      ) do
    expiry_date = Date.from_iso8601!(expiry_date)
    duration = Date.diff(expiry_date, Date.utc_today())

    expiry_date
    |> calculate_reminders(duration)
    |> Enum.each(fn date ->
      add_reminder(current_user, instance, %{
        "reminder_date" => date,
        "recipients" => default_recipients
      })
    end)
  end

  def maybe_create_auto_reminders(_current_user, _instance), do: :ok

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

  defp send_email_notification(
         %Reminder{content: %Instance{instance_id: instance_id, serialized: serialized}} =
           reminder
       ) do
    reminder
    |> get_recipients()
    |> Enum.each(fn recipient ->
      %{
        user_name: recipient.name,
        email: recipient.email,
        instance_id: instance_id,
        document_title: serialized["title"]
      }
      |> EmailWorker.new(tags: ["document_reminder"])
      |> Oban.insert()
    end)

    Logger.info("Email notifications scheduled for reminder #{reminder.id}")

    reminder
  end

  defp send_in_app_notification(
         %Reminder{content: %Instance{instance_id: instance_id, serialized: serialized}} =
           reminder
       ) do
    reminder
    |> get_recipients()
    |> Enum.map(& &1.id)
    |> Notifications.create_notification(%{
      type: :document_reminder,
      instance_id: instance_id,
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
end
