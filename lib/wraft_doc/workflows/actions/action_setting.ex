defmodule WraftDoc.Workflows.Actions.ActionSetting do
  @moduledoc """
  ActionSetting schema - stores custom action configurations per organization.

  Allows organizations to customize action default configs and descriptions.
  """
  use WraftDoc.Schema

  schema "action_settings" do
    field(:action_id, :string)
    field(:name, :string)
    field(:description, :string)
    field(:default_config, :map, default: %{})
    field(:is_active, :boolean, default: true)

    belongs_to(:organisation, WraftDoc.Enterprise.Organisation)

    timestamps(type: :utc_datetime)
  end

  def changeset(setting, attrs) do
    setting
    |> cast(attrs, [
      :action_id,
      :name,
      :description,
      :default_config,
      :is_active,
      :organisation_id
    ])
    |> validate_required([:action_id, :organisation_id])
    |> unique_constraint([:action_id, :organisation_id],
      name: :action_settings_action_id_organisation_id_index
    )
  end
end
