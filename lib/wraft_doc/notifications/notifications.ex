defmodule WraftDoc.Notifications do
  @moduledoc """
  Context for notification
  """
  import Ecto.Query

  alias Ecto.Multi
  alias WraftDoc.Account
  alias WraftDoc.Account.User
  alias WraftDoc.Documents
  alias WraftDoc.Documents.Instance
  alias WraftDoc.Enterprise
  alias WraftDoc.Enterprise.Organisation
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
  def create_notification(users, params) when is_list(users) do
    users
    |> Enum.map(&build_notification_params(&1, params))
    |> Enum.map(&insert_notification/1)
    |> Enum.split_with(&match?({:ok, _}, &1))
    |> format_results()
  end

  def create_notification(_), do: nil

  defp build_notification_params(%{id: actor_id}, params) do
    params
    |> Map.put(:actor_id, actor_id)
    |> Map.put(:message, NotificationMessages.message(params.type, params))
  end

  defp insert_notification(notification_params) do
    Multi.new()
    |> Multi.insert(:notification, Notification.changeset(%Notification{}, notification_params))
    |> Multi.run(:fetch_recipient, &fetch_recipient/2)
    |> Multi.insert(:user_notification, fn %{
                                             notification: notification,
                                             fetch_recipient: recipient
                                           } ->
      UserNotifications.changeset(%UserNotifications{}, %{
        notification_id: notification.id,
        actor_id: notification_params.actor_id,
        recipient_id: recipient.id
      })
    end)
    |> Multi.run(:broadcast, fn _repo,
                                %{notification: notification, fetch_recipient: recipient} ->
      broadcast_notification(notification.message, recipient)
      {:ok, :broadcast_success}
    end)
    |> Repo.transaction()
    |> handle_transaction_result()
  end

  def broadcast_notification(notification, recipient) do
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

  defp handle_transaction_result({:ok, %{notification: notification}}), do: {:ok, notification}
  defp handle_transaction_result({:error, _, reason, _}), do: {:error, reason}

  defp format_results({successes, []}), do: {:ok, Enum.map(successes, fn {:ok, n} -> n end)}
  defp format_results({_, [{:error, reason} | _]}), do: {:error, reason}

  defp fetch_recipient(_repo, %{notification: %{actor_id: actor_id}}) do
    case Account.get_user(actor_id) do
      nil -> {:error, :user_not_found}
      user -> {:ok, user}
    end
  end

  @doc """
  Sends a comment notification to users allowed to access a document, excluding the initiating user.
  """
  @spec comment_notification(integer(), integer(), integer()) :: list(%Notification{})
  def comment_notification(user_id, organisation_id, document_id) do
    document = Documents.get_instance(document_id, %{current_org_id: organisation_id})
    organisation = Enterprise.get_organisation(organisation_id)

    document.allowed_users
    |> List.delete(user_id)
    |> Enum.map(&Account.get_user/1)
    |> create_notification(%{
      type: :add_comment,
      organisation_name: organisation.name,
      document_title: document.serialized["title"]
    })
  end

  @doc """
  Notification for the Documet flow
  """
  def document_notification(
        %User{name: approver_name} = _current_user,
        %Instance{serialized: %{"title" => document_title}} = _instance,
        %Organisation{name: organisation_name} = _organisation,
        state
      ) do
    new_state = Documents.next_state(state)

    with {:ok, _} <-
           create_notification(state.approvers, %{
             type: :state_update,
             document_title: document_title,
             organisation_name: organisation_name,
             state_name: state.state,
             approver_name: approver_name
           }),
         {:ok, _} <-
           create_notification(new_state.approvers, %{
             type: :pending_approvals,
             document_title: document_title,
             organisation_name: organisation_name,
             state_name: new_state.state
           }) do
      {:ok, :notifications_sent}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  List unread notifications for an user
  ## Parameters
  * `current_user`- user struct
  """
  @spec list_unread_notifications(User.t(), map) :: map
  def list_unread_notifications(%User{} = user, params) do
    UserNotifications
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
  def unread_notification_count(%User{} = user) do
    UserNotifications
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
    UserNotifications
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
  @spec get_user_notification(User.t(), Ecto.UUID.t()) :: UserNotifications.t() | nil
  def get_user_notification(%User{} = current_user, notification_id) do
    UserNotifications
    |> where(
      [un],
      un.recipient_id == ^current_user.id and un.notification_id == ^notification_id and
        un.status == :unread
    )
    |> Repo.one()
  end
end
