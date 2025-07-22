defmodule WraftDoc.Notifications.Notification do
  @moduledoc """
  Notification Module
  """
  use WraftDoc.Schema

  @derive {Jason.Encoder,
           only: [
             :event_type,
             :message,
             :channel,
             :channel_id,
             :action,
             :organisation_id,
             :metadata,
             :actor_id
           ]}
  @fields [
    :event_type,
    :message,
    :channel_id,
    :channel,
    :action,
    :organisation_id,
    :metadata,
    :actor_id
  ]
  @channel_values [
    :user_notification,
    :role_group_notification,
    :organisation_notification,
    :announcement
  ]

  schema "notifications" do
    field(:event_type, :string)
    field(:message, :string)
    field(:is_global, :boolean, default: false)

    field(:channel, Ecto.Enum,
      values: @channel_values,
      default: :user_notification
    )

    field(:channel_id, :string)
    field(:action, :map, default: %{})
    field(:metadata, :map, default: %{})

    belongs_to(:actor, WraftDoc.Account.User)
    belongs_to(:organisation, WraftDoc.Enterprise.Organisation)

    timestamps()
  end

  def changeset(notification, attrs \\ %{}) do
    notification
    |> cast(attrs, @fields)
    |> validate_required([:message, :event_type])
  end
end
