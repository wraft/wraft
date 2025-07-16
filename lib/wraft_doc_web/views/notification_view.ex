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
      action: notification.action,
      actor: render_one(notification.actor, UserView, "actor.json"),
      meta: notification.metadata,
      inserted_at: notification.inserted_at
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
        render_many(notifications, NotificationView, "user_notification.json",
          as: :user_notification
        ),
      page_number: page_number,
      total_pages: total_pages,
      total_entries: total_entries
    }
  end

  def render("user_notification.json", %{user_notification: user_notification}) do
    Map.merge(
      %{
        read: user_notification.read,
        seen_at: user_notification.seen_at
      },
      render_one(user_notification.notification, NotificationView, "notification.json")
    )
  end

  def render("count.json", %{count: count}) do
    %{count: count}
  end

  def render("mark_as_read.json", %{info: info}) do
    %{
      info: info
    }
  end

  def render("settings.json", %{settings: settings}) do
    %{
      id: settings.id,
      events: settings.events,
      organisation: render_one(settings.organisation, OrganisationView, "organisation.json")
    }
  end

  def render("events.json", %{events: events}) do
    %{
      events: events
    }
  end
end
