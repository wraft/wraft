defmodule WraftDocWeb.Api.V1.NotificationView do
  use WraftDocWeb, :view

  alias WraftDocWeb.Api.V1.OrganisationView
  alias WraftDocWeb.Api.V1.UserView
  alias __MODULE__

  def render("notification.json", %{notification: notification}) do
    %{
      id: notification.id,
      event_type: notification.event_type,
      message: notification.message,
      is_global: notification.is_global,
      action: notification.action,
      # actor: render_one(notification.actor, UserView, "user.json"),
      inserted_at: notification.inserted_at,
      updated_at: notification.updated_at
    }
  end

  def render("index.json", %{
        notifications: notifications,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      }) do
    %{
      notifications:
        render_many(notifications, NotificationView, "notification.json", as: :notification),
      page_number: page_number,
      total_pages: total_pages,
      total_entries: total_entries
    }
  end

  def render("index_read.json", %{
        notifications: notifications,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      }) do
    %{
      notifications:
        render_many(notifications, NotificationView, "user_notification.json",
          as: :user_notification
        ),
      page_number: page_number,
      total_pages: total_pages,
      total_entries: total_entries
    }
  end

  def render("index_unread.json", %{
        notifications: notifications,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      }) do
    %{
      notifications:
        render_many(notifications, NotificationView, "user_notification.json",
          as: :user_notification
        ),
      page_number: page_number,
      total_pages: total_pages,
      total_entries: total_entries
    }
  end

  def render("user_notification.json", %{user_notification: user_notification}) do
    %{
      id: user_notification.id,
      status: user_notification.status,
      seen_at: user_notification.seen_at,
      inserted_at: user_notification.inserted_at,
      updated_at: user_notification.updated_at,
      organisation:
        render_one(user_notification.organisation, OrganisationView, "organisation.json"),
      recipient: render_one(user_notification.recipient, UserView, "user.json"),
      notification:
        render_one(user_notification.notification, NotificationView, "notification.json")
    }
  end

  def render("count.json", %{count: count}) do
    %{count: count}
  end

  def render("mark_as_read.json", %{info: info}) do
    %{
      info: info
    }
  end
end
