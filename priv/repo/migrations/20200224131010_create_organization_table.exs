defmodule WraftDoc.Repo.Migrations.CreateOrganizationTable do
  use Ecto.Migration

  def up do
    create table(:organisation) do
      add(:uuid, :uuid, null: false)
      add(:name, :string, null: false)
      timestamps()
    end

    alter table(:user) do
      add(:uuid, :uuid, null: false)
      add(:organisation_id, references(:organisation))
    end

    create(unique_index(:organisation, :name, name: :organisation_unique_index))
  end

  def down do
    alter table(:user) do
      remove(:uuid)
      remove(:organisation_id)
    end

    drop_if_exists(table(:organisation))
  end
end
