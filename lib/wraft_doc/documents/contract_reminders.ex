defmodule WraftDoc.Documents.ContractReminders do
  @moduledoc """
  Context module for managing contract reminders.
  """

  alias WraftDoc.Documents
  alias WraftDoc.Documents.ContractReminder
  alias WraftDoc.Documents.Instance
  alias WraftDoc.Notifications
  alias WraftDoc.Repo
  alias WraftDoc.Valkey.ValkeyServer
  alias WraftDoc.Workers.EmailWorker

  require Logger
  import Ecto.Query

  @doc """
  List all reminders for a contract
  """
  def list_reminders(contract_instance_id) do
    contract_instance_id
    |> ContractReminder.for_instance()
    |> Repo.all()
  end

  @doc """
  Get a specific reminder
  """
  def get_reminder(id) do
    ContractReminder
    |> Repo.get(id)
    |> case do
      nil -> {:error, :not_found}
      reminder -> {:ok, reminder}
    end
  end

  @doc """
  Add a new reminder for a contract
  """
  def add_reminder(contract_instance_id, reminder_attrs) do
    case Documents.get_instance(contract_instance_id) do
      %Instance{} = instance ->
        %ContractReminder{}
        |> ContractReminder.changeset(Map.merge(reminder_attrs, %{"instance_id" => instance.id}))
        |> Repo.insert()
        |> maybe_store_in_valkey(instance.id)

      nil ->
        {:error, :instance_not_found}
    end
  end

  @doc """
  Update an existing reminder
  """
  def update_reminder(contract_instance_id, reminder_id, reminder_attrs) do
    with {:ok, reminder} <- get_reminder_for_instance(reminder_id, contract_instance_id) do
      reminder
      |> ContractReminder.update_changeset(reminder_attrs)
      |> Repo.update()
      |> maybe_update_in_valkey(contract_instance_id)
    end
  end

  @doc """
  Delete a reminder
  """
  def delete_reminder(contract_instance_id, reminder_id) do
    with {:ok, reminder} <- get_reminder_for_instance(reminder_id, contract_instance_id) do
      result = Repo.delete(reminder)
      remove_from_valkey(contract_instance_id, reminder_id)
      result
    end
  end

  @doc """
  Process scheduled reminders that are due
  This function is called by a scheduled job
  """
  def process_scheduled_reminders do
    # Get all pending reminders that are due today or earlier
    ContractReminder.upcoming_reminders_query()
    |> Repo.all()
    |> Enum.each(&process_reminder/1)
  end

  # Private functions

  defp get_reminder_for_instance(reminder_id, instance_id) do
    ContractReminder
    |> where([r], r.id == ^reminder_id and r.instance_id == ^instance_id)
    |> Repo.one()
    |> case do
      nil -> {:error, :not_found}
      reminder -> {:ok, reminder}
    end
  end

  defp maybe_store_in_valkey({:ok, reminder} = result, instance_id) do
    if reminder.manual_date do
      # Store in Valkey for faster lookups and TTL
      store_in_valkey(instance_id, reminder)
    end

    result
  end

  defp maybe_store_in_valkey(error, _), do: error

  defp maybe_update_in_valkey({:ok, reminder} = result, instance_id) do
    if reminder.manual_date do
      # Update in Valkey
      update_in_valkey(instance_id, reminder)
    end

    result
  end

  defp maybe_update_in_valkey(error, _), do: error

  defp store_in_valkey(instance_id, reminder) do
    # Store the reminder in Valkey with TTL based on the reminder date
    key = "contract_reminder:#{instance_id}:#{reminder.id}"

    # Calculate TTL in seconds until the reminder date
    ttl = calculate_ttl_for_reminder(reminder)

    # Skip if TTL is already passed
    if ttl > 0 do
      # Store in Valkey
      ValkeyServer.set(key, Jason.encode!(reminder), ex: ttl)
    end
  end

  defp update_in_valkey(instance_id, reminder) do
    # Update reminder in Valkey
    key = "contract_reminder:#{instance_id}:#{reminder.id}"

    # Calculate TTL in seconds until the reminder date
    ttl = calculate_ttl_for_reminder(reminder)

    # Store in Valkey
    if ttl > 0 do
      ValkeyServer.set(key, Jason.encode!(reminder), ex: ttl)
    else
      # If date is in the past, remove the key
      ValkeyServer.del(key)
    end
  end

  defp remove_from_valkey(instance_id, reminder_id) do
    # Remove reminder from Valkey
    key = "contract_reminder:#{instance_id}:#{reminder_id}"
    ValkeyServer.del(key)
  end

  defp calculate_ttl_for_reminder(reminder) do
    today = Date.utc_today()
    days_diff = Date.diff(reminder.reminder_date, today)

    # Convert days to seconds (24 hours * 60 minutes * 60 seconds)
    days_diff * 24 * 60 * 60
  end

  defp process_reminder(reminder) do
    # Mark reminder as sent
    reminder
    |> ContractReminder.sent_changeset()
    |> Repo.update()
    |> case do
      {:ok, updated_reminder} ->
        # Send notifications
        send_reminder_notifications(updated_reminder)

        # Remove from Valkey if it was stored there
        remove_from_valkey(updated_reminder.instance_id, updated_reminder.id)

        {:ok, updated_reminder}

      error ->
        Logger.error("Failed to mark reminder as sent: #{inspect(error)}")
        error
    end
  end

  defp send_reminder_notifications(reminder) do
    case reminder.notification_type do
      :both ->
        send_email_notification(reminder)
        send_in_app_notification(reminder)

      :email ->
        send_email_notification(reminder)

      :in_app ->
        send_in_app_notification(reminder)

      _ ->
        Logger.warning("Unknown notification type", type: reminder.notification_type)
    end
  end

  defp send_email_notification(reminder) do
    # Get recipients
    recipients = get_recipients(reminder)

    # Schedule email notification for each recipient
    Enum.each(recipients, fn recipient ->
      %{
        user_name: recipient.name,
        notification_message: reminder.message,
        email: recipient.email
      }
      |> EmailWorker.new()
      |> Oban.insert()
    end)

    Logger.info("Email notifications scheduled for reminder #{reminder.id}")
  end

  defp send_in_app_notification(reminder) do
    # Get recipients
    recipients = get_recipients(reminder)

    # Create in-app notification for each recipient
    recipient_ids = Enum.map(recipients, & &1.id)

    Notifications.create_notification(recipient_ids, %{
      type: :contract_reminder,
      message: reminder.message,
      document_id: reminder.instance_id,
      document_title: reminder.instance.serialized["title"]
    })

    # Broadcast to each recipient over PubSub for live updates
    Enum.each(recipient_ids, fn recipient_id ->
      Phoenix.PubSub.broadcast(
        WraftDoc.PubSub,
        "user:#{recipient_id}",
        {:contract_reminder, %{instance_id: reminder.instance_id, reminder: reminder}}
      )
    end)

    Logger.info("In-app notifications sent for reminder #{reminder.id}")
  end

  defp get_recipients(reminder) do
    # Get the recipients from the reminder configuration
    # If not specified, use the document creator and collaborators
    case reminder.recipients do
      recipients when is_list(recipients) and length(recipients) > 0 ->
        # Lookup users by IDs
        recipients
        |> Enum.map(&WraftDoc.Account.get_user/1)
        |> Enum.reject(&is_nil/1)

      _ ->
        # Default to document creator and collaborators
        [reminder.instance.user_id | Documents.get_collaborator_ids(reminder.instance_id)]
        |> Enum.uniq()
        |> Enum.map(&WraftDoc.Account.get_user/1)
        |> Enum.reject(&is_nil/1)
    end
  end
end
