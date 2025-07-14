defmodule WraftDoc.Notifications.Settings do
  @moduledoc """
  This module defines the Notification Preference schema.
  """
  use WraftDoc.Schema

  schema "notification_preferences" do
    embeds_one(:preference, Preference) do
      field(:in_app, :boolean, default: true)
      field(:email, :boolean, default: true)
    end

    belongs_to(:organisation, WraftDoc.Enterprise.Organisation)

    timestamps()
  end

  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:event_id, :organisation_id])
    |> cast_embed(:preference)
    |> validate_required([:event_id, :organisation_id])
  end
end
