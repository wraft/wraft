defmodule WraftDoc.Repo.Migrations.CreateAccessControlTables do
  use Ecto.Migration

  def up do
    create table(:resource) do
      add(:uuid, :uuid, null: false)
      add(:category, :string, null: false)
      add(:action, :string, null: false)
    end

    create table(:permission) do
      add(:uuid, :uuid, null: false)
      add(:resource_id, references(:resource))
      add(:role_id, references(:role))
    end

    create(unique_index(:permission, [:resource_id, :role_id], name: :permission_unique_index))
  end

  def down do
    drop_if_exists(table(:permission))
    drop_if_exists(table(:resource))
  end
end
