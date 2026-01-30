defmodule WraftDoc.Repo.Migrations.UpdateLayoutTableAddCover do
  use Ecto.Migration

  def up do
    alter table(:layouts) do
      add(:cover_id, references(:asset, type: :uuid, column: :id, on_delete: :nilify_all))
      add(:metadata, :map)
    end
  end

  def down do
    alter table(:layouts) do
      remove(:cover_id)
      remove(:metadata)
    end
  end
end
