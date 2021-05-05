defmodule WraftDoc.Notifications do
  @moduledoc """
  Context for notification
  """
  import Ecto.Query

  alias WraftDoc.{Account.User, Notifications.Notification, Repo}
  alias WraftDocWeb.Worker.EmailWorker

  @doc """
  Create notification entry
  """
  def create_notification(
        recipient,
        actor_id \\ nil,
        action,
        notifiable_id \\ nil,
        notifiable_type
      ) do
    attrs = %{
      recipient_id: recipient.id,
      actor_id: actor_id,
      action: action,
      notifiable_id: notifiable_id,
      notifiable_type: notifiable_type
    }

    %Notification{}
    |> Notification.changeset(attrs)
    |> Repo.insert!()
    |> broad_cast_notifiation(recipient)
  end

  def create_notification(%{"recipient_id" => recipient_uuid, "actor_id" => actor_uuid} = params) do
    recipient = Repo.get_by(User, uuid: recipient_uuid)
    actor = Repo.get_by(User, uuid: actor_uuid)

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
      id: notification.uuid,
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

  def read_notification(notification) do
    params = %{read_at: Timex.now(), read: true}

    notification
    |> Notification.read_changeset(params)
    |> Repo.update!()
  end
end
