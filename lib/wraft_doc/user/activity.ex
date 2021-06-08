defmodule WraftDoc.Account.Activity do
  @moduledoc """
  Schema for activity table
  """
  use WraftDoc.Schema

  schema "activity" do
    field(:action, :string)
    field(:actor, :string)
    field(:object, :string)
    field(:target, :string)
    field(:meta, :map)
    field(:inserted_at, :utc_datetime)
  end

  def changeset(activity, attrs) do
    activity
    |> cast(attrs, [:action, :actor, :object, :target, :meta, :inserted_at])
    |> validate_required([:action])
  end
end
