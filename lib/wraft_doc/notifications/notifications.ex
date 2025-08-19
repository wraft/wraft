defmodule WraftDoc.Notifications do
  @moduledoc """
  Context for notification
  """
  import Ecto.Query

  alias WraftDoc.Account
  alias WraftDoc.Account.User
  alias WraftDoc.Notifications.Notification
  alias WraftDoc.Notifications.Settings
  alias WraftDoc.Notifications.Template
  alias WraftDoc.Notifications.UserNotification
  alias WraftDoc.Repo
  alias WraftDoc.Workers.EmailWorker

  @doc """
  Creates a notification for the current user's organization.

  This function creates a single notification record in the database for the
  current user's organization, merging the provided parameters with the
  organization ID.

  ## Parameters
  - `current_user`: A user struct containing `current_org_id` field
  - `params`: A map containing notification details. This map **must** include:
    - `:event_type` - String identifying the notification type (e.g., "document.share")
    - `:message` - String containing the notification message
    - `:channel` - Atom indicating the notification channel (optional, defaults to :user_notification)
    - `:channel_id` - String identifying the target channel (optional)
    - `:action` - Map containing action details (optional)

  ## Returns
  - `{:ok, notification}`: A tuple containing `:ok` and the successfully created `Notification` struct
  - `{:error, changeset}`: A tuple containing `:error` and an `Ecto.Changeset` if validation fails

  ## Examples
      iex> create_notification(current_user, %{
      ...>   event_type: "document.share",
      ...>   message: "Document shared with you",
      ...>   channel: :user_notification,
      ...>   channel_id: "user_123"
      ...> })
      {:ok, %Notification{}}
  """
  @spec create_notification(User.t(), map()) ::
          {:ok, Notification.t()} | {:error, Ecto.Changeset.t()}
  def create_notification(
        %{id: user_id, current_org_id: current_org_id} = _current_user,
        params
      ) do
    params
    |> Map.merge(%{
      actor_id: user_id,
      organisation_id: current_org_id
    })
    |> then(&Notification.changeset(%Notification{}, &1))
    |> Repo.insert()
    |> case do
      {:ok, notification} ->
        notification
        |> Repo.preload(actor: [:profile])
        |> then(&{:ok, &1})

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  List unread notifications for an user
  ## Parameters
  * `current_user`- user struct
  """
  @spec list_notifications(User.t(), map()) :: map()
  def list_notifications(%User{} = user, params) do
    user
    |> unread_from_user_notifications()
    |> union_all(^unread_from_notifications(user))
    |> order_by([un], desc: fragment("?", 7))
    |> Repo.paginate(params)
    |> preload_associations()
  end

  defp unread_from_user_notifications(%User{} = user) do
    from(un in UserNotification,
      where: un.recipient_id == ^user.id,
      select: %{
        id: un.id,
        read: un.read,
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
        read: fragment("false::boolean"),
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
      |> Repo.preload([
        :recipient,
        :organisation,
        notification: [:organisation, actor: [:profile]]
      ])

    %Scrivener.Page{result | entries: preloaded_entries}
  end

  @doc """
  Mark a notification as read for a specific user.

  This function creates a UserNotification record marking the given notification
  as read for the specified user. If the notification is already marked as read,
  this will fail due to unique constraint.

  ## Parameters
  - `user`: A user struct containing `current_org_id` and `id` fields
  - `notification`: A notification struct to mark as read

  ## Returns
  - `{:ok, user_notification}`: A tuple containing `:ok` and the created `UserNotification` struct
  - `{:error, changeset}`: A tuple containing `:error` and an `Ecto.Changeset` if creation fails

  ## Examples
      iex> read_notification(current_user, notification)
      {:ok, %UserNotification{read: true}}
  """
  @spec read_notification(User.t(), Notification.t()) ::
          {:ok, UserNotification.t()} | {:error, Ecto.Changeset.t()}
  def read_notification(%{id: user_id, current_org_id: current_org_id} = _user, notification) do
    %UserNotification{}
    |> UserNotification.changeset(%{
      seen_at: Timex.now(),
      read: true,
      notification_id: notification.id,
      recipient_id: user_id,
      organisation_id: current_org_id
    })
    |> Repo.insert()
  end

  @doc """
  Count unread notifications for a user.

  This function counts the number of unread notifications for the given user
  by querying UserNotification records with read false.

  ## Parameters
  - `user`: A user struct containing the `id` field

  ## Returns
  - `integer`: The count of unread notifications

  ## Examples
      iex> unread_notification_count(current_user)
      5
  """
  @spec unread_notification_count(User.t()) :: integer
  def unread_notification_count(%User{} = user) do
    user
    |> unread_from_notifications()
    |> Repo.all()
    |> Enum.count()
  end

  @doc """
  Mark all unread notifications as read for a user.

  This function finds all unread notifications for the user in their current
  organization and creates UserNotification records marking them as read.
  It uses bulk insert for performance.

  ## Parameters
  - `current_user`: A user struct containing `id` and `current_org_id` fields

  ## Returns
  - `{count, nil}`: A tuple containing the number of notifications marked as read and `nil`

  ## Examples
      iex> read_all_notifications(current_user)
      {3, nil}
  """
  @spec read_all_notifications(User.t()) :: {integer(), nil}
  def read_all_notifications(%User{id: user_id, current_org_id: organisation_id} = user) do
    user_role_ids = Account.get_user_role_ids(user)

    unread_notification_ids =
      Notification
      |> join(:left, [n], un in UserNotification,
        on: un.notification_id == n.id and un.recipient_id == ^user_id
      )
      |> where(
        [n, _un],
        n.organisation_id == ^organisation_id and
          (n.channel == :organisation_notification or
             (n.channel == :user_notification and n.channel_id == ^user_id) or
             (n.channel == :role_group_notification and n.channel_id in ^user_role_ids))
      )
      |> where([_n, un], is_nil(un.id))
      |> select([n, _un], n.id)
      |> Repo.all()

    entries =
      Enum.map(unread_notification_ids, fn notification_id ->
        %{
          notification_id: notification_id,
          recipient_id: user_id,
          organisation_id: organisation_id,
          read: true,
          seen_at: DateTime.truncate(DateTime.utc_now(), :second),
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
  Get a specific unread user notification.

  This function retrieves a UserNotification record for the given user and
  notification ID, but only if the notification is still unread.

  ## Parameters
  - `current_user`: A user struct containing the `id` field
  - `notification_id`: UUID of the notification to retrieve

  ## Returns
  - `UserNotification.t()`: The user notification struct if found and unread
  - `nil`: If no unread notification found with the given ID

  ## Examples
      iex> get_user_notification(current_user, "123e4567-e89b-12d3-a456-426614174000")
      %UserNotification{read: false}
  """
  @spec get_user_notification(User.t(), Ecto.UUID.t()) :: UserNotification.t() | nil
  def get_user_notification(%User{} = current_user, notification_id) do
    UserNotification
    |> where(
      [un],
      un.recipient_id == ^current_user.id and un.notification_id == ^notification_id and
        un.read == false
    )
    |> Repo.one()
  end

  @doc """
  Get a notification by ID within the user's organization.

  This function retrieves a notification record by its ID, but only if it
  belongs to the user's current organization for security purposes.

  ## Parameters
  - `current_user`: A user struct containing the `current_org_id` field
  - `notification_id`: UUID of the notification to retrieve

  ## Returns
  - `Notification.t()`: The notification struct if found within the user's organization
  - `nil`: If no notification found with the given ID in the user's organization

  ## Examples
      iex> get_notification(current_user, "123e4567-e89b-12d3-a456-426614174000")
      %Notification{event_type: "document.share"}
  """
  @spec get_notification(User.t(), Ecto.UUID.t()) :: Notification.t() | nil
  def get_notification(%User{current_org_id: current_org_id} = _current_user, notification_id),
    do: Repo.get_by(Notification, id: notification_id, organisation_id: current_org_id)

  @doc """
  Send an email notification to a recipient.

  This function creates and enqueues an email job for sending a notification
  to a specific recipient. It uses the EmailWorker to handle the actual email
  sending asynchronously.

  ## Parameters
  - `notification`: A notification struct containing at least a `message` field
  - `recipient`: A recipient struct containing `name` and `email` fields

  ## Returns
  - `{:ok, job}`: If the email job was successfully enqueued
  - `{:error, reason}`: If the email job failed to enqueue
  - `nil`: If the notification or recipient is invalid

  ## Examples
      iex> email_notification(notification, %{name: "John", email: "john@example.com"})
      {:ok, %Oban.Job{}}
  """
  @spec email_notification(map(), map()) :: {:ok, Oban.Job.t()} | {:error, term()} | nil
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

  @doc """
  Get notification settings for the user's organization.

  This function retrieves the notification settings configured for the user's
  current organization, including preloaded organization details.

  ## Parameters
  - `current_user`: A user struct containing the `current_org_id` field

  ## Returns
  - `Settings.t()`: The organization's notification settings with preloaded organization
  - `nil`: If no settings found for the organization

  ## Examples
      iex> get_organisation_settings(current_user)
      %Settings{events: ["document.share", "document.comment"]}
  """
  @spec get_organisation_settings(User.t()) :: Settings.t() | nil
  def get_organisation_settings(%User{current_org_id: current_org_id} = _current_user)
      when not is_nil(current_org_id) do
    Settings
    |> Repo.get_by(organisation_id: current_org_id)
    |> case do
      %Settings{} = settings -> settings
      _ -> %Settings{events: []}
    end
  end

  def get_organisation_settings(_user) do
    %Settings{events: []}
  end

  @doc """
  Update notification settings for an organization.

  This function updates the notification settings for an organization with the
  provided parameters. It validates the changes and returns the updated settings
  with preloaded organization details.

  ## Parameters
  - `settings`: A Settings struct representing the current organization settings
  - `params`: A map containing the fields to update (e.g., %{events: ["document.share"]})

  ## Returns
  - `{:ok, settings}`: A tuple containing `:ok` and the updated Settings struct with preloaded organization
  - `{:error, settings}`: A tuple containing `:error` and the original Settings struct if update fails

  ## Examples
      iex> update_organisation_settings(settings, %{events: ["document.share"]})
      {:ok, %Settings{events: ["document.share"]}}
  """
  @spec create_or_update_organisation_settings(Settings.t(), map()) ::
          {:ok, Settings.t()} | {:error, Settings.t()}
  def create_or_update_organisation_settings(
        %{current_org_id: current_org_id} = _current_user,
        params
      ) do
    with {:ok, params} <- validate_events(params) do
      Settings
      |> Repo.get_by(organisation_id: current_org_id)
      |> case do
        nil ->
          %Settings{}
          |> Settings.changeset(Map.merge(params, %{"organisation_id" => current_org_id}))
          |> Repo.insert()

        settings ->
          settings
          |> Settings.changeset(params)
          |> Repo.update()
      end
    end
  end

  def validate_events(%{"events" => events} = params) when is_list(events) do
    valid_events = Template.list_notification_types()

    filtered_events =
      events
      |> Enum.filter(&(&1 in valid_events))
      |> Enum.uniq()

    {:ok, Map.put(params, "events", filtered_events)}
  end

  def validate_events(_, _), do: {:error, "Invalid notification event"}
end
