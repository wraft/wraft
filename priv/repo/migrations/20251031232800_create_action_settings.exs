defmodule WraftDoc.Repo.Migrations.CreateActionSettings do
  use Ecto.Migration

  def up do
    create table(:action_settings, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:action_id, :string, null: false)
      add(:name, :string)
      add(:description, :string)
      add(:default_config, :map, default: %{})
      add(:is_active, :boolean, default: true, null: false)

      add(:organisation_id, references(:organisation, type: :uuid, on_delete: :delete_all),
        null: false
      )

      timestamps(type: :utc_datetime)
    end

    create(unique_index(:action_settings, [:action_id, :organisation_id]))
    create(index(:action_settings, [:organisation_id]))
    create(index(:action_settings, [:is_active]))
  end

  def down do
    drop_if_exists(table(:action_settings))
  end
end
