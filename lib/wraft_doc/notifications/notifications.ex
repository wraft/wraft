defmodule WraftDoc.Notifications do
  @moduledoc """
  Context for notification
  """
  import Ecto.Query

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
  def create_notification(
        %{id: user_id, current_org_id: current_org_id} = current_user,
        %{event_type: event_type} = params
      ) do
    params
    |> Map.merge(%{
      actor_id: user_id,
      message: NotificationMessages.message(event_type, params),
      organisation_id: current_org_id
    })
    |> then(&Notification.changeset(%Notification{}, &1))
    |> Repo.insert()
    |> case do
      {:ok, notification} ->
        NotificationChannel.broad_cast(notification, current_user)
        {:ok, notification}

      {:error, _, reason, _} ->
        {:error, reason}
    end
  end

  @doc """
  List unread notifications for an user
  ## Parameters
  * `current_user`- user struct
  """
  @spec list_unread_notifications(User.t(), map()) :: map()
  def list_unread_notifications(%User{id: user_id, current_org_id: current_org_id} = user, params) do
    Notification
    |> where(
      [n],
      n.organisation_id == ^current_org_id and
        (n.channel == :organisation_notification or
           (n.channel == :user_notification and n.channel_id == ^user_id) or
           (n.channel == :role_group_notification and
              n.channel_id in ^Account.get_user_role_ids(user)))
    )
    |> join(:left, [n], un in UserNotification,
      on: un.notification_id == n.id and un.recipient_id == ^user_id
    )
    |> where([n, un], is_nil(un.id))
    |> order_by([n], desc: n.inserted_at)
    |> Repo.paginate(params)
  end

  @doc """
  List read notifications for an user
  ## Parameters
  * `current_user`- user struct
  """
  @spec list_read_notifications(User.t(), map()) :: map()
  def list_read_notifications(%User{id: user_id, current_org_id: current_org_id} = _user, params) do
    UserNotification
    |> where([un], un.organisation_id == ^current_org_id)
    |> where([un], un.recipient_id == ^user_id)
    |> where([un], un.status == :read)
    |> order_by([un], desc: un.inserted_at)
    |> preload([:notification, :organisation, :recipient])
    |> Repo.paginate(params)
  end

  @doc """
  Mark notification as read
  ## Parameters
  * `user_notification`- user notification struct
  """
  @spec read_notification(User.t(), Notification.t()) ::
          {:ok, UserNotification.t()} | {:error, Ecto.Changeset.t()}
  def read_notification(user, notification) do
    %UserNotification{}
    |> UserNotification.changeset(%{
      seen_at: Timex.now(),
      status: "read",
      notification_id: notification.id,
      recipient_id: user.id
    })
    |> Repo.insert()
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
  def read_all_notifications(%User{id: user_id, current_org_id: organisation_id} = _current_user) do
    unread_notification_ids =
      Notification
      |> join(:left, [n], un in UserNotification,
        on:
          un.notification_id == n.id and
            un.recipient_id == ^user_id
      )
      |> where([n, _un], n.organisation_id == ^organisation_id)
      |> where([_n, un], is_nil(un.id))
      |> select([n, _un], n.id)
      |> Repo.all()

    entries =
      Enum.map(unread_notification_ids, fn notification_id ->
        %{
          notification_id: notification_id,
          recipient_id: user_id,
          organisation_id: organisation_id,
          status: :read,
          inserted_at: NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second),
          updated_at: NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)
        }
      end)

    if entries != [] do
      Repo.insert_all(UserNotification, entries)
    else
      {0, nil}
    end
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

  @doc """
  Get notification
  ## Parameters
  * `current_user`- user struct
  * `notification` - notification struct
  """
  @spec get_notification(User.t(), Ecto.UUID.t()) :: Notification.t() | nil
  def get_notification(%User{current_org_id: current_org_id} = _current_user, notification_id),
    do: Repo.get_by(Notification, id: notification_id, organisation_id: current_org_id)

  # def dispatch(:both, notification, user) do
  #   dispatch(:email, notification, user)
  #   dispatch(:in_app, notification, user)
  # end

  # def dispatch(:email, notification, user) do
  #   email_notification(notification, user)
  # end

  # def dispatch(:in_app, notification, user) do
  #   # Implementation for in-app dispatcher
  # end

  def email_notification(
        notification,
        %{name: name, email: email} = _recipient
      ) do
    %{
      user_name: name,
      notification_message: notification,
      email: email
    }
    |> EmailWorker.new(
      queue: "mailer",
      tags: ["notification"]
    )
    |> Oban.insert()
  end

  def email_notification(_, _, _, _), do: nil
end
