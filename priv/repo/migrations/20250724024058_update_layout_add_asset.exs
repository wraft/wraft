defmodule WraftDoc.Repo.Migrations.UpdateLayoutAddAsset do
  use Ecto.Migration

  def up do
    alter table(:layouts) do
      add(:asset_id, references(:asset, type: :uuid, column: :id, on_delete: :nilify_all))
    end
  end

  def down do
    alter table(:layouts) do
      remove(:asset_id)
    end
  end
end
