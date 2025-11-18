defmodule WraftDoc.Workflows.AdapterSetting do
  @moduledoc """
  AdapterSetting schema - stores adapter enable/disable settings per organization.
  """
  use WraftDoc.Schema

  schema "adapter_settings" do
    field(:adapter_name, :string)
    field(:is_enabled, :boolean, default: true)
    field(:config, :map, default: %{})

    belongs_to(:organisation, WraftDoc.Enterprise.Organisation)

    timestamps(type: :utc_datetime)
  end

  def changeset(setting, attrs) do
    setting
    |> cast(attrs, [:adapter_name, :is_enabled, :config, :organisation_id])
    |> validate_required([:adapter_name, :organisation_id])
    |> unique_constraint([:adapter_name, :organisation_id],
      name: :adapter_settings_adapter_name_organisation_id_index
    )
  end
end
