defmodule WraftDoc.Notifications.Notification do
  @moduledoc """
  Notification Module
  """
  use WraftDoc.Schema

  schema "notification" do
    field(:read_at, :naive_datetime)
    field(:read, :boolean, default: false)
    field(:action, :string)
    field(:notifiable_id, Ecto.UUID)
    field(:notifiable_type, WraftDoc.EctoType.AtomType)
    belongs_to(:recipient, WraftDoc.Account.User)
    belongs_to(:actor, WraftDoc.Account.User)

    timestamps()
  end

  # TODO write test for these changesets
  def changeset(notification, attrs \\ %{}) do
    notification
    |> cast(attrs, [
      :action,
      :notifiable_id,
      :notifiable_type,
      :read_at,
      :read,
      :actor_id,
      :recipient_id
    ])
    |> validate_required([:actor_id, :recipient_id, :action])
  end

  def read_changeset(notification, attrs \\ %{}) do
    notification
    |> cast(attrs, [
      :read_at,
      :read
    ])
    |> validate_required([:read_at, :read])
  end
end
