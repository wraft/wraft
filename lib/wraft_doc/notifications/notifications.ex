defmodule WraftDoc.Notifications do
  @moduledoc """
  Context for notification
  """
  import Ecto.Query

  alias WraftDoc.Account
  alias WraftDoc.Account.User
  alias WraftDoc.Notifications.Notification
  alias WraftDoc.Notifications.Settings
  alias WraftDoc.Notifications.UserNotification
  alias WraftDoc.Repo
  alias WraftDoc.Workers.EmailWorker

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
        %{current_org_id: current_org_id} = _current_user,
        params
      ) do
    params
    |> Map.merge(%{
      organisation_id: current_org_id
    })
    |> then(&Notification.changeset(%Notification{}, &1))
    |> Repo.insert()
  end

  @doc """
  List unread notifications for an user
  ## Parameters
  * `current_user`- user struct
  """
  @spec list_notifications(User.t(), map()) :: map()
  def list_notifications(%User{} = user, params) do
    params
    |> Map.get("status", "unread")
    |> case do
      "unread" ->
        user
        |> unread_from_user_notifications()
        |> union_all(^unread_from_notifications(user))
        |> order_by([un], desc: fragment("?", 7))
        |> Repo.paginate(params)
        |> preload_associations()

      "read" ->
        UserNotification
        |> where([un], un.recipient_id == ^user.id and un.status == :read)
        |> order_by([un], desc: un.inserted_at)
        |> preload([:notification, :organisation, :recipient])
        |> Repo.paginate(params)
    end
  end

  defp unread_from_user_notifications(%User{} = user) do
    from(un in UserNotification,
      where: un.recipient_id == ^user.id and un.status == :unread,
      select: %{
        id: un.id,
        status: un.status,
        seen_at: un.seen_at,
        organisation_id: un.organisation_id,
        recipient_id: un.recipient_id,
        notification_id: un.notification_id,
        inserted_at: un.inserted_at,
        updated_at: un.updated_at
      }
    )
  end

  defp unread_from_notifications(%User{id: user_id, current_org_id: org_id} = user) do
    from(n in Notification,
      where:
        n.organisation_id == ^org_id and
          (n.channel == :organisation_notification or
             (n.channel == :user_notification and n.channel_id == ^user_id) or
             (n.channel == :role_group_notification and
                n.channel_id in ^Account.get_user_role_ids(user))),
      left_join: un in UserNotification,
      on: un.notification_id == n.id and un.recipient_id == ^user_id,
      where: is_nil(un.id),
      select: %{
        id: fragment("NULL::uuid"),
        status: fragment("'unread'::text"),
        seen_at: fragment("NULL::timestamp"),
        organisation_id: n.organisation_id,
        recipient_id: type(^user_id, :binary_id),
        notification_id: n.id,
        inserted_at: n.inserted_at,
        updated_at: n.updated_at
      }
    )
  end

  defp preload_associations(%Scrivener.Page{entries: entries} = result) do
    preloaded_entries =
      entries
      |> Enum.map(fn user_notification_map ->
        struct(UserNotification, user_notification_map)
      end)
      |> Repo.preload([:recipient, :organisation, notification: [:organisation]])

    %Scrivener.Page{result | entries: preloaded_entries}
  end

  @doc """
  Mark notification as read
  ## Parameters
  * `user_notification`- user notification struct
  """
  @spec read_notification(User.t(), Notification.t()) ::
          {:ok, UserNotification.t()} | {:error, Ecto.Changeset.t()}
  def read_notification(%{current_org_id: current_org_id} = user, notification) do
    %UserNotification{}
    |> UserNotification.changeset(%{
      seen_at: Timex.now(),
      status: "read",
      notification_id: notification.id,
      recipient_id: user.id,
      organisation_id: current_org_id
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

  def email_notification(
        %{message: message} = _notification,
        %{name: name, email: email} = _recipient
      ) do
    %{
      user_name: name,
      notification_message: message,
      email: email
    }
    |> EmailWorker.new(
      queue: "mailer",
      tags: ["notification"]
    )
    |> Oban.insert()
  end

  def email_notification(_, _), do: nil

  def get_organisation_settings(%User{current_org_id: current_org_id} = _current_user),
    do: Settings |> Repo.get_by(organisation_id: current_org_id) |> Repo.preload(:organisation)

  def update_organisation_settings(%Settings{} = settings, params) do
    settings
    |> Settings.changeset(params)
    |> Repo.update()
    |> case do
      {:ok, _} -> {:ok, Repo.preload(settings, :organisation)}
      {:error, _} -> {:error, settings}
    end
  end
end
