defmodule WraftDocWeb.Api.V1.NotificationController do
  use WraftDocWeb, :controller

  plug(WraftDocWeb.Plug.Authorized)
  plug(WraftDocWeb.Plug.AddActionLog)
  action_fallback(WraftDocWeb.FallbackController)
  use PhoenixSwagger

  alias WraftDoc.Notifications

  def swagger_definitions do
    %{
      NotificationRequest:
        swagger_schema do
          title("Notification request")
          description("Notification ")

          properties do
            action(:string, "action")
            recipient_id(:string, "Recipient id")
          end

          example(%{
            action: "assigned_as_approver",
            recipient_id: "125sdd1f51sf"
          })
        end
    }
  end

  swagger_path :create do
    post("/notifications")
    summary("create notification")

    parameters do
      notification(:body, Schema.ref(:NotificationRequest), "Notification to be created",
        required: true
      )
    end

    response(200, "Ok", Schema.ref(:OrganisationFieldRequest))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  def create(conn, params) do
    notification = Notifications.create_notification(params)
    render(conn, "notification.json", notification: notification)
  end
end
