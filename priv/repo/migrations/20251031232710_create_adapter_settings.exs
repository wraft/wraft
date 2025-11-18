defmodule WraftDoc.Repo.Migrations.CreateAdapterSettings do
  use Ecto.Migration

  def up do
    create table(:adapter_settings, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:adapter_name, :string, null: false)

      add(:organisation_id, references(:organisation, type: :uuid, on_delete: :delete_all),
        null: false
      )

      add(:is_enabled, :boolean, default: true, null: false)
      add(:config, :map, default: %{})

      timestamps(type: :utc_datetime)
    end

    create(unique_index(:adapter_settings, [:adapter_name, :organisation_id]))
    create(index(:adapter_settings, [:organisation_id]))
    create(index(:adapter_settings, [:is_enabled]))
  end

  def down do
    drop_if_exists(table(:adapter_settings))
  end
end
