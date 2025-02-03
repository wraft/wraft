defmodule WraftDoc.Notifications do
  @moduledoc """
  Context for notification
  """
  import Ecto.Query

  alias Ecto.Multi
  alias WraftDoc.Account
  alias WraftDoc.Account.User
  alias WraftDoc.Document
  alias WraftDoc.Enterprise
  alias WraftDoc.Notifications.Notification
  alias WraftDoc.Notifications.NotificationMessages
  alias WraftDoc.Notifications.UserNotifications
  alias WraftDoc.Repo
  alias WraftDoc.Workers.EmailWorker
  alias WraftDocWeb.NotificationChannel

  @doc """
  Create notification entry
  """

  def create_notification(users, params) when is_list(users) do
    users
    |> Enum.map(fn user ->
      create_notification(user, params)
    end)
    |> Enum.reduce({:ok, []}, fn
      {:ok, notification}, {:ok, acc} -> {:ok, [notification | acc]}
      {:error, reason}, _ -> {:error, reason}
    end)
    |> case do
      {:ok, notifications} -> {:ok, Enum.reverse(notifications)}
      {:error, reason} -> {:error, reason}
    end
  end

  def create_notification(user, params) do
    params =
      Map.merge(params, %{
        actor_id: user.id,
        type: params[:type],
        message: NotificationMessages.message(params[:type], params)
      })

    Multi.new()
    |> Multi.insert(:notification, Notification.changeset(%Notification{}, params))
    |> Multi.run(:fetch_recipient, fn _repo, _changes ->
      fetch_user(params.actor_id)
    end)
    |> Multi.insert(:user_notification, fn %{
                                             notification: notification,
                                             fetch_recipient: recipient
                                           } ->
      UserNotifications.changeset(%UserNotifications{}, %{
        notification_id: notification.id,
        actor_id: user.id,
        recipient_id: recipient.id
      })
    end)
    |> Multi.run(:broadcast, fn _repo,
                                %{notification: notification, fetch_recipient: recipient} ->
      broad_cast_notifiation(notification.message, recipient)
      {:ok, :broadcast_sucess}
    end)
    |> Repo.transaction()

    # TODO improve email and other
    # |> case do
    #   {:ok, %{notification: notification, fetch_recipient: recipient}} ->
    #     with :ok <- schedule_email(notification, recipient) do
    #       {:ok, notification}
    #     end

    #   {:error, reason} ->
    #     {:error, reason}
    # end
  end

  def create_notification(_), do: nil

  def comment_notifcation(user_id, organisation_id, document_id) do
    document = Document.get_instance(document_id, %{current_org_id: organisation_id})
    organisation = Enterprise.get_organisation(organisation_id)
    user = Account.get_user(user_id)

    document.allowed_users
    |> List.delete(user)
    |> Enum.map(&Account.get_user/1)
    |> create_notification(%{
      type: :assign_role,
      organisation_name: organisation.name,
      document_title: document.serialized["title"]
    })
  end

  def broad_cast_notifiation(notification, recipient) do
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

    NotificationChannel.broad_cast(notification, recipient)
  end

  defp fetch_user(nil), do: {:error, :invalid_recipient}

  defp fetch_user(id) do
    case Repo.get(User, id) do
      nil -> {:error, :invalid_recipient}
      user -> {:ok, user}
    end
  end

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

  # def schedule_email(notification, recipient) do
  #   %{
  #     user_name: recipient.name,
  #     notification_message: notification.message,
  #     email: recipient.email
  #   }
  #   |> EmailWorker.new(
  #     queue: Application.get_env(:wraft_doc, :notification_queue, "mailer"),
  #     tags: ["notification"],
  #     max_attempts: 3
  #   )
  #   |> Oban.insert()
  #   |> case do
  #     {:ok, _job} -> :ok
  #     {:error, reason} -> {:error, reason}
  #   end
  # end

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
end
