defmodule WraftDoc.Notifications.Notification do
  @moduledoc """
  Notification Module
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "notification" do
    field(:uuid, Ecto.UUID, autogenerate: true, null: false)
    field(:read_at, :naive_datetime)
    field(:read, :boolean, default: false)
    field(:action, :string)
    field(:notifiable_id, :integer)
    field(:notifiable_type, AtomType)

    timestamps()
  end

  def changeset(notification, attrs \\ %{}) do
    notification
    |> cast(attrs, [
      :action,
      :notifiable_id,
      :notifiable_type,
      :read_at,
      :read
    ])
    |> validate_required([:notifiable_type])
  end
end
