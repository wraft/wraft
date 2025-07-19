defmodule WraftDoc.Notifications.UserNotification do
  @moduledoc """
  User Notifications Module
  """
  alias __MODULE__
  use WraftDoc.Schema

  @fields [:read, :seen_at, :organisation_id, :recipient_id, :notification_id]

  schema "user_notifications" do
    field(:read, :boolean, default: false)
    field(:seen_at, :utc_datetime)

    belongs_to(:organisation, WraftDoc.Enterprise.Organisation)
    belongs_to(:recipient, WraftDoc.Account.User)
    belongs_to(:notification, WraftDoc.Notifications.Notification)

    timestamps()
  end

  def changeset(%UserNotification{} = user_notification, attrs) do
    user_notification
    |> cast(attrs, @fields)
    |> validate_required([:read])
    |> unique_constraint([:recipient_id, :notification_id],
      message: "has already been notified",
      name: :unique_user_notification
    )
    |> foreign_key_constraint(:notification_id, message: "Please enter a valid notification")
    |> foreign_key_constraint(:recipient_id, message: "Please enter a valid user")
    |> foreign_key_constraint(:organisation_id, message: "Please enter a valid organisation")
  end

  def status_update_changeset(%UserNotification{} = user_notification, attrs) do
    user_notification
    |> cast(attrs, [:read, :seen_at])
    |> validate_required([:read, :seen_at])
  end
end
