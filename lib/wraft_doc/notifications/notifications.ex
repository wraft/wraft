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
  Creates notifications for a list of users based on given parameters.
  Returns a list of successfully created notifications or an error.
  """
  def create_notification(users, params) do
    users
    |> Enum.map(&build_notification_params(&1, params))
    |> Enum.map(&insert_notification/1)
    |> Enum.split_with(&match?({:ok, _}, &1))
    |> format_results()
  end

  def create_notification(_), do: nil

  defp build_notification_params(%{id: actor_id} = _user, %{type: type} = params) do
    params
    |> Map.put(:actor_id, actor_id)
    |> Map.put(:message, NotificationMessages.message(type, params))
  end

  defp insert_notification(notification_params) do
    Multi.new()
    |> Multi.insert(:notification, Notification.changeset(%Notification{}, notification_params))
    |> Multi.run(:fetch_recipient, fn _repo, _changes ->
      Account.get_user(notification_params.actor_id)
    end)
    |> Multi.insert(:user_notification, &build_user_notification/2)
    |> Multi.run(:broadcast, &broadcast_notification_result/2)
    |> Repo.transaction()
    |> handle_transaction_result()
  end

  defp build_user_notification(
         %{notification: %{id: notification_id}, fetch_recipient: %{id: recipient_id}},
         _changes
       ) do
    UserNotifications.changeset(%UserNotifications{}, %{
      notification_id: notification_id,
      actor_id: notification_id,
      recipient_id: recipient_id
    })
  end

  defp broadcast_notification_result(_repo, %{
         notification: %{message: message},
         fetch_recipient: recipient
       }) do
    broadcast_notification(message, recipient)
    {:ok, :broadcast_success}
  end

  defp handle_transaction_result({:ok, %{notification: notification}}), do: {:ok, notification}
  defp handle_transaction_result({:error, _, reason, _}), do: {:error, reason}

  defp format_results({successes, []}), do: {:ok, Enum.map(successes, fn {:ok, n} -> n end)}
  defp format_results({_, [{:error, reason} | _]}), do: {:error, reason}

  defp broadcast_notification(notification, recipient) do
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

  @doc """
  Sends a comment notification to users allowed to access a document, excluding the initiating user.
  """
  @spec comment_notification(integer(), integer(), integer()) :: list(%Notification{})
  def comment_notification(user_id, organisation_id, document_id) do
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
end
