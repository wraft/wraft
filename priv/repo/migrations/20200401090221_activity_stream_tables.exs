defmodule WraftDoc.Repo.Migrations.ActivityStreamTables do
  use Ecto.Migration

  def up do
    create table(:activity, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:action, :string, null: false)
      add(:actor, :string)
      add(:object, :string)
      add(:target, :string)
      add(:meta, :map)

      timestamps(updated_at: false)
    end

    create table(:audience, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:activity_id, references(:activity, type: :uuid, column: :id, on_delete: :nilify_all))
      add(:user_id, references(:user, type: :uuid, column: :id, on_delete: :nilify_all))
    end
  end

  def down do
    drop_if_exists(table(:audience))
    drop_if_exists(table(:activity))
  end
end
