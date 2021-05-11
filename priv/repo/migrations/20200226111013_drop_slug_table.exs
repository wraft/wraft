defmodule WraftDoc.Repo.Migrations.DropSlugTable do
  use Ecto.Migration

  def up do
    alter table(:layout) do
      remove(:slug_id)
      add(:slug, :string)
    end

    drop_if_exists(table(:slug))
    create(unique_index(:engine, :name, name: :engine_name_unique_index))
  end

  def down do
    create table(:slug, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:name, :string)
      add(:creator_id, references(:user, type: :uuid, column: :id, on_delete: :nilify_all))
      timestamps()
    end

    alter table(:layout) do
      remove(:slug)
      add(:slug_id, references(:slug, type: :uuid, column: :id, on_delete: :nilify_all))
    end

    drop(unique_index(:engine, :name, name: :engine_name_unique_index))
  end
end
