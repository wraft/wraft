defmodule WraftDoc.Repo.Migrations.RemoveContentTypesFromBlocks do
  use Ecto.Migration

  def up do
    alter table(:block) do
      remove(:content_type_id)
    end
  end

  def down do
    alter table(:block) do
      add(:content_type_id, references(:content_type, on_delete: :nilify_all))
    end
  end
end
