defmodule WraftDoc.Notifications do
  @moduledoc """
  Context for notification
  """
  import Ecto.Query

  alias Ecto.Multi
  alias WraftDoc.Account
  alias WraftDoc.Account.User
  alias WraftDoc.Notifications.Notification
  alias WraftDoc.Notifications.NotificationMessages
  alias WraftDoc.Notifications.UserNotification
  alias WraftDoc.Repo
  alias WraftDoc.Workers.EmailWorker
  alias WraftDocWeb.NotificationChannel

  @doc """
  Creates notifications for a list of users based on given parameters.

  This function iterates through the provided list of `users`, builds a notification
  for each, persists them to the database, and enqueues background jobs for
  email and real-time (in-app) broadcasts.

  ## Parameters
  - `users`: A list of `WraftDoc.Account.User` structs (or user IDs) for whom
             the notifications are to be created.
  - `params`: A map containing notification details. This map **must** include an
              `:event_type` atom (e.g., `:add_comment`, `:mention_comment`),
              which determines the message content via `NotificationMessages`,
              and may contain other data specific to the event type.

  ## Returns
  - `{:ok, notifications}`: A tuple containing `:ok` and a list of successfully
                           created `Notification` structs.
  - `{:error, reason}`: A tuple containing `{:error, reason}` if any notification
                       creation or associated transaction fails.
  """
  def create_notification(user_id, %{event_type: event_type} = params) do
    params
    |> Map.merge(%{
      actor_id: user_id,
      message: NotificationMessages.message(event_type, params)
    })
    |> do_create_notification()
  end

  defp do_create_notification(%{actor_id: actor_id} = params) do
    user = Account.get_user(actor_id)

    Multi.new()
    |> Multi.insert(:notification, Notification.changeset(%Notification{}, params))
    |> Multi.insert(
      :user_notification,
      fn %{
           notification: notification
         } ->
        UserNotification.changeset(%UserNotification{}, %{
          notification_id: notification.id,
          recipient_id: user.id
        })
      end
    )
    |> Repo.transaction()
    |> handle_transaction_result(user)
  end

  defp handle_transaction_result(
         {:ok, %{notification: %{event_type: event_type} = notification}},
         user
       ) do
    email_notification(notification, event_type, :user, user)
    {:ok, notification}
  end

  defp handle_transaction_result({:error, _, reason, _}, _user), do: {:error, reason}

  def email_notification(%{channel: channel} = notification, event, scope, recipient)
      when channel in [:email, :all] do
    %{
      user_name: recipient.name,
      notification_message: notification,
      email: recipient.email
    }
    |> EmailWorker.new(
      queue: "mailer",
      tags: ["notification"]
    )
    |> Oban.insert()

    broadcast_notification(notification, event, scope, recipient)
  end

  def email_notification(_, _, _, _), do: nil

  # TODO lets try with oban. for check
  def broadcast_notification(notification, event, scope, recipient) do
    NotificationChannel.broad_cast(notification, event, scope, recipient)
  end

  @doc """
  List unread notifications for an user
  ## Parameters
  * `current_user`- user struct
  """
  @spec list_unread_notifications(User.t(), map) :: map
  def list_unread_notifications(%User{} = user, params) do
    UserNotification
    |> where(
      [un],
      un.recipient_id == ^user.id and un.status == :unread
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
  @spec read_notification(UserNotification.t()) :: UserNotification.t()
  def read_notification(user_notification) do
    user_notification
    |> UserNotification.status_update_changeset(%{seen_at: Timex.now(), status: "read"})
    |> Repo.update!()
  end

  @doc """
  Count unread notifications for an user
  ## Parameters
  * `current_user`- user struct
  """
  @spec unread_notification_count(User.t()) :: integer
  def unread_notification_count(%User{} = user) do
    UserNotification
    |> where(
      [un],
      un.recipient_id == ^user.id and un.status == :unread
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
  def read_all_notifications(%User{} = current_user) do
    UserNotification
    |> where(
      [un],
      un.recipient_id == ^current_user.id and
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
  @spec get_user_notification(User.t(), Ecto.UUID.t()) :: UserNotification.t() | nil
  def get_user_notification(%User{} = current_user, notification_id) do
    UserNotification
    |> where(
      [un],
      un.recipient_id == ^current_user.id and un.notification_id == ^notification_id and
        un.status == :unread
    )
    |> Repo.one()
  end
end
