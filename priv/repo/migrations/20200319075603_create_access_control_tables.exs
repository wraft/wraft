defmodule WraftDoc.Repo.Migrations.CreateAccessControlTables do
  use Ecto.Migration

  def up do
    create table(:resource, primary_key: false) do
      add(:id, primary_key: true)
      add(:category, :string, null: false)
      add(:action, :string, null: false)
    end

    create table(:permission, primary_key: false) do
      add(:id, primary_key: true)
      add(:resource_id, references(:resource, type: :uuid, column: :id, on_delete: :nilify_all))
      add(:role_id, references(:role, type: :uuid, column: :id, on_delete: :nilify_all))
    end

    create(unique_index(:permission, [:resource_id, :role_id], name: :permission_unique_index))
  end

  def down do
    drop_if_exists(table(:permission))
    drop_if_exists(table(:resource))
  end
end
