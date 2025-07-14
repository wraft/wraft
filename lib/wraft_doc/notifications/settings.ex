defmodule WraftDoc.Notifications.Settings do
  @moduledoc """
  This module defines the Notification Preference schema.
  """
  use WraftDoc.Schema

  schema "notification_settings" do
    field(:events, {:array, :string}, default: [])
    belongs_to(:organisation, WraftDoc.Enterprise.Organisation)

    timestamps()
  end

  def changeset(settings, params \\ %{}) do
    settings
    |> cast(params, [:events, :organisation_id])
    |> validate_required([:events, :organisation_id])
  end
end
