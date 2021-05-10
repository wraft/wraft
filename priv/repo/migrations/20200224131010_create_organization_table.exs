defmodule WraftDoc.Repo.Migrations.CreateOrganizationTable do
  use Ecto.Migration

  def up do
    create table(:organisation, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:name, :string, null: false)
      timestamps()
    end

    alter table(:user) do
      add(
        :organisation_id,
        references(:organisation, type: :uuid, column: :id, on_delete: :nilify_all)
      )
    end

    create(unique_index(:organisation, :name, name: :organisation_unique_index))
  end

  def down do
    alter table(:user) do
      remove(:organisation_id)
    end

    drop_if_exists(table(:organisation))
  end
end
