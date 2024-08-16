defmodule WraftDoc.Notifications do
  @moduledoc """
  Context for notification
  """
  import Ecto.Query

  alias WraftDoc.Account.User
  alias WraftDoc.Notifications.Notification
  alias WraftDoc.Notifications.UserNotifications
  alias WraftDoc.Repo
  alias WraftDoc.Workers.EmailWorker

  @doc """
  Create notification entry
  """
  def create_notification(user, params) do
    %Notification{}
    |> Notification.changeset(Map.merge(params, %{"actor_id" => user.id}))
    |> Repo.insert!()

    # |> broad_cast_notifiation(recipient)
  end

  def create_notification(%{"recipient_id" => recipient_uuid, "actor_id" => actor_uuid} = params) do
    recipient = Repo.get_by(User, id: recipient_uuid)
    actor = Repo.get_by(User, id: actor_uuid)

    params =
      Map.merge(params, %{
        "recipient_id" => recipient.id,
        "actor_id" => actor.id
      })

    %Notification{}
    |> Notification.changeset(params)
    |> Repo.insert()
    |> case do
      {:ok, notification} ->
        broad_cast_notifiation(notification, recipient)
        notification

      {:error, _} = changeset ->
        changeset
    end
  end

  def create_notification(_), do: nil

  def broad_cast_notifiation(notification, recipient) do
    %{
      user_name: recipient.name,
      notification_message: get_email_message(notification),
      email: recipient.email
    }
    |> EmailWorker.new(
      queue: "mailer",
      tags: ["notification"]
    )
    |> Oban.insert()

    message = get_notification_message(notification)

    WraftDocWeb.NotificationChannel.broad_cast(message, recipient)
    # WraftDoc.NotificationChannel.broad_cast(notification.recipient_id)
  end

  @doc """
  List notifications for an user
  ## Parameters
  * `current_user`- user struct
  """
  def list_notifications(current_user) do
    query =
      from(n in Notification,
        where: n.recipient_id == ^current_user.id,
        order_by: [desc: n.inserted_at],
        preload: [:actor]
      )

    Repo.all(query)
  end

  @doc """
  Returns notification message for particular action
  ## Parameters
  * `notification` - notification struct
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
  ## Parameters
  * `current_user`- user struct
  """
  @spec list_unread_notifications(User.t(), map) :: map
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
  ## Parameters
  * `user_notification`- user notification struct
  """
  @spec read_notification(UserNotifications.t()) :: UserNotifications.t()
  def read_notification(user_notification) do
    user_notification
    |> UserNotifications.status_update_changeset(%{seen_at: Timex.now(), status: "read"})
    |> Repo.update!()
  end

  @doc """
  Count unread notifications for an user
  ## Parameters
  * `current_user`- user struct
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
  ## Parameters
  * `current_user`- user struct
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
  ## Parameters
  * `current_user`- user struct
  * `notification` - notification struct
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

  def insert_user_notification do
    %UserNotifications{}
    |> UserNotifications.changeset(%{
      recipient_id: "397b8443-4abe-42cc-89ba-6fcd6923c70d",
      notification_id: "5d1aefa0-a754-415e-afb8-c03499bee706"
    })
    |> Repo.insert()
  end
end
