defmodule WraftDoc.Repo.Migrations.ActivityStreamTables do
  use Ecto.Migration

  def up do
    create table(:activity) do
      add(:action, :string, null: false)
      add(:actor, :string)
      add(:object, :string)
      add(:meta, :map)

      timestamps(updated_at: false)
    end

    create table(:audience) do
      add(:activity_id, references(:activity))
      add(:user_id, references(:user))
    end
  end

  def down do
    drop_if_exists(table(:audience))
    drop_if_exists(table(:activity))
  end
end
