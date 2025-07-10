defmodule WraftDoc.Notifications.Notification do
  @moduledoc """
  Notification Module
  """
  use WraftDoc.Schema

  @derive {Jason.Encoder, only: [:event_type, :message, :actor_id]}
  @fields [:event_type, :message, :action, :actor_id]

  schema "notification" do
    field(:event_type, WraftDoc.EctoType.AtomType)
    field(:message, :string)
    field(:is_global, :boolean, default: false)
    field(:channel, Ecto.Enum, values: [:all, :email, :in_app], default: :all)
    field(:scope, Ecto.Enum, values: [:user, :role, :organization], default: :user)
    field(:action, :map, default: %{})
    belongs_to(:actor, WraftDoc.Account.User)

    timestamps()
  end

  # TODO write test for these changesets
  def changeset(notification, attrs \\ %{}) do
    notification
    |> cast(attrs, @fields)
    |> validate_required([:message, :event_type])
  end
end
