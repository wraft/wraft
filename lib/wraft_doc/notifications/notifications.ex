defmodule WraftDoc.Notifications do
  @moduledoc """
  Context for notification
  """
  import Ecto.Query

  alias WraftDoc.Account.User
  alias WraftDoc.Notifications.Notification
  alias WraftDoc.Notifications.NotificationServer
  alias WraftDoc.Notifications.UserNotifications
  alias WraftDoc.Repo
  alias WraftDoc.Workers.EmailWorker

  @doc """
  Create notification entry
  """

  def create_notification(%User{} = actor, params) when is_map(params) do
    with {:ok, recipient} <- fetch_user(params["recipient_id"]),
         {:ok, notification} <- make_notification(actor, recipient, params),
         {:ok, _user_notifcation} <-
           make_user_notification(actor, recipient, notification.id),
         :ok <- handle_notification(notification, recipient),
         :ok <- schedule_email(notification, recipient) do
      {:ok, notification}
    else
      {:error, _reason} = error ->
        error
    end
  end

  def create_notification(_), do: nil

  defp fetch_user(nil), do: {:error, :invalid_recipient}

  defp fetch_user(id) do
    case Repo.get(User, id) do
      nil -> {:error, :invalid_recipient}
      user -> {:ok, user}
    end
  end

  defp make_notification(actor, recipient, params) do
    notification_params =
      Map.merge(params, %{
        "actor_id" => actor.id,
        "recipient_id" => recipient.id
      })

    %Notification{}
    |> Notification.changeset(notification_params)
    |> Repo.insert()
  end

  defp make_user_notification(_actor, recipient, notification_id) do
    user_notification_params = %{
      "notification_id" => notification_id,
      "recipient_id" => recipient.id,
      "status" => :unread
    }

    %UserNotifications{}
    |> UserNotifications.changeset(user_notification_params)
    |> Repo.insert()
  end

  defp handle_notification(notification, recipient) do
    message = format_notification_message(notification)
    # TODO # additional funtions , type of notification , scope of notification
    NotificationServer.broadcast_notification(message, recipient)
    :ok
  rescue
    _exception ->
      {:error, :broadcast_failed}
  end

  defp schedule_email(notification, recipient) do
    %{
      user_name: recipient.name,
      notification_message: format_email_message(notification),
      email: recipient.email
    }
    |> EmailWorker.new(
      queue: Application.get_env(:wraft_doc, :notification_queue, "mailer"),
      tags: ["notification"],
      max_attempts: 3
    )
    |> Oban.insert()
    |> case do
      {:ok, _job} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  List notifications for an user
  """
  def list_notifications(%User{} = current_user) do
    Notification
    |> where([n], n.recipient_id == ^current_user.id)
    |> order_by(desc: :inserted_at)
    |> preload(:actor)
    |> Repo.all()
  end

  @doc """
  Returns notification message for particular action
  """
  def get_notification_message(notification) do
    message =
      case notification.action do
        "assigned_as_approver" ->
          "You have been assigned to approve a document"
      end

    %{
      id: notification.id,
      read_at: notification.read_at,
      read: notification.read,
      action: notification.action,
      message: message,
      notifiable_id: notification.notifiable_id,
      notifiable_type: notification.notifiable_type
    }
  end

  def get_email_message(notification) do
    case notification.action do
      "assigned_as_approver" ->
        "You have been assigned to approve a document"
    end
  end

  @doc """
  List unread notifications for an user
  """
  def list_unread_notifications(%User{current_org_id: org_id} = user, params) do
    UserNotifications
    |> where(
      [un],
      un.recipient_id == ^user.id and un.organisation_id == ^org_id and un.status == :unread
    )
    |> order_by([un], desc: un.inserted_at)
    |> preload([{:notification, :actor}, :organisation, :recipient])
    |> Repo.paginate(params)
  end

  @doc """
  Mark notification as read
  """
  @spec read_notification(UserNotifications.t()) :: UserNotifications.t()
  def read_notification(user_notification) do
    user_notification
    |> UserNotifications.status_update_changeset(%{seen_at: Timex.now(), status: "read"})
    |> Repo.update!()
  end

  @doc """
  Count unread notifications for an user
  """
  @spec unread_notification_count(User.t()) :: integer
  def unread_notification_count(%User{current_org_id: org_id} = user) do
    UserNotifications
    |> where(
      [un],
      un.recipient_id == ^user.id and un.organisation_id == ^org_id and un.status == :unread
    )
    |> select([un], count(un.id))
    |> Repo.one()
  end

  @doc """
  Mark all notifications as read
  """
  @spec read_all_notifications(User.t()) :: {integer(), nil}
  def read_all_notifications(%User{current_org_id: org_id} = current_user) do
    UserNotifications
    |> where(
      [un],
      un.recipient_id == ^current_user.id and un.organisation_id == ^org_id and
        un.status == :unread
    )
    |> Repo.update_all(set: [seen_at: Timex.now(), status: "read"])
  end

  @doc """
  Get user notification
  """
  @spec get_user_notification(User.t(), Ecto.UUID.t()) :: UserNotifications.t() | nil
  def get_user_notification(%User{current_org_id: org_id} = current_user, notification_id) do
    UserNotifications
    |> where(
      [un],
      un.recipient_id == ^current_user.id and un.notification_id == ^notification_id and
        un.organisation_id == ^org_id and un.status == :unread
    )
    |> Repo.one()
  end

  @doc """
  Formats a notification message based on its action.
  """
  @spec format_notification_message(Notification.t()) :: map
  def format_notification_message(
        %WraftDoc.Notifications.Notification{action: %{"type" => "assigned_as_approver"}} =
          notification
      ) do
    %{
      id: notification.id,
      message: "You have been assigned to approve a document"
    }
  end

  @doc """
  Formats the email message for a notification.
  """
  @spec format_email_message(Notification.t()) :: String.t()
  def format_email_message(%Notification{action: "assigned_as_approver"}) do
    "You have been assigned to approve a document"
  end
end
