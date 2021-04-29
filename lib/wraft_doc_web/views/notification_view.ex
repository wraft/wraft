defmodule WraftDocWeb.Api.V1.NotificationView do
  use WraftDocWeb, :view

  def render("notification.json", %{notification: notification}) do
    %{
      id: notification.uuid,
      action: notification.action,
      actor_id: notification.actor_id,
      recipient_id: notification.recipient_id
    }
  end
end
