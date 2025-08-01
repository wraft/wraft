defmodule WraftDoc.Repo.Migrations.RevampLayoutAssetEntriesIntoLayout do
  use Ecto.Migration

  def up do
    execute("""
    UPDATE layouts
    SET asset_id = sub.asset_id
    FROM (
      SELECT DISTINCT ON (layout_id) layout_id, asset_id
      FROM layout_asset
      ORDER BY layout_id, inserted_at DESC
    ) AS sub
    WHERE layouts.id = sub.layout_id
    """)

    drop(table(:layout_asset))
  end

  def down do
    create table(:layout_asset, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:layout_id, references(:layouts, type: :uuid, column: :id, on_delete: :nilify_all))
      add(:asset_id, references(:asset, type: :uuid, column: :id, on_delete: :nilify_all))
      add(:creator_id, references(:user, type: :uuid, column: :id, on_delete: :nilify_all))
      timestamps()
    end
  end
end
