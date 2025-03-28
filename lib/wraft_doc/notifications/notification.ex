defmodule WraftDoc.Notifications.Notification do
  @moduledoc """
  Notification Module
  """
  use WraftDoc.Schema

  @derive {Jason.Encoder, only: [:type, :message, :actor_id]}
  @fields [:type, :message, :action, :actor_id]

  schema "notification" do
    field(:type, WraftDoc.EctoType.AtomType)
    field(:message, :string)
    field(:is_global, :boolean, default: false)
    field(:action, :map, default: %{})
    belongs_to(:actor, WraftDoc.Account.User)

    timestamps()
  end

  # TODO write test for these changesets
  def changeset(notification, attrs \\ %{}) do
    notification
    |> cast(attrs, @fields)
    |> validate_required([:message, :type])
  end
end
