defmodule WraftDoc.Notifications.Delivery do
  @moduledoc """
  Handles delivering notifications through different channels (in-app, email, etc).
  """

  import Ecto.Query
  require Logger

  alias WraftDoc.Notifications
  alias WraftDoc.Notifications.Template
  alias WraftDoc.{Account, Repo}
  alias WraftDocWeb.NotificationChannel
  # alias WraftDoc.Workers.EmailWorker

  @doc """
  Delivers a notification to a list of users through configured delivery channels.
  """
  def dispatch(current_user, type, params) do
    delivery_channels = Template.get_channels(type)

    with {:ok, notification_record} <-
           create_notification_record(current_user, type, params),
         :ok <-
           send_through_delivery_channels(
             current_user,
             notification_record,
             delivery_channels,
             params
           ) do
      {:ok, notification_record}
    end
  end

  defp create_notification_record(current_user, type, params) do
    message = Template.render_message(type, params)

    Notifications.create_notification(
      current_user,
      Map.merge(
        %{
          event_type: type,
          message: message,
          is_global: false,
          action: Map.get(params, :action, %{})
        },
        params
      )
    )
  end

  defp send_through_delivery_channels(current_user, notification, delivery_channels, params) do
    Enum.each(delivery_channels, fn delivery_channel ->
      send_through_delivery_channel(delivery_channel, current_user, notification, params)
    end)
  end

  defp send_through_delivery_channel(:in_app, current_user, notification, _params),
    do: NotificationChannel.broad_cast(notification, current_user)

  defp send_through_delivery_channel(:email, current_user, notification, _params) do
    with {:ok, _email_config} <- Template.get_email_config(notification.event_type) do
      notification
      |> get_channel_users(current_user)
      |> Enum.each(fn user_id ->
        user = Account.get_user(user_id)

        # email_params =
        #   Map.merge(params, %{
        #     user_name: user.name,
        #     email: user.email,
        #     notification_message: notification.message
        #   })

        # %{
        #   template: email_config.template,
        #   subject: email_config.subject.(params),
        #   params: email_params
        # }
        # |> EmailWorker.new(
        #   queue: "mailer",
        #   tags: ["notification", to_string(notification.event_type)]
        # )
        # |> Oban.insert()
        Notifications.email_notification(notification, user)
      end)
    end
  end

  defp send_through_delivery_channel(unknown_channel, _, _notification, _params),
    do: Logger.warning("Unknown notification channel: #{inspect(unknown_channel)}")

  defp get_channel_users(
         %{channel: channel, channel_id: channel_id} = _notification,
         %{id: user_id} = _current_user
       ) do
    case channel do
      :user_notification ->
        [channel_id || user_id]

      :role_group_notification ->
        Account.get_role_users(channel_id)

      # get list of user ids
      :organisation_notification ->
        # Enterprise.members_index(current_user, %{})
        User
        |> join(:inner, [u], uo in UserOrganisation, on: uo.user_id == u.id)
        |> where([u, uo], uo.organisation_id == ^channel_id)
        |> select([u], u.id)
        |> Repo.all()

      _ ->
        User
        |> select([u], u.id)
        |> Repo.all()
    end
  end
end
