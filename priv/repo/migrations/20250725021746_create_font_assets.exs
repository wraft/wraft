defmodule WraftDoc.Repo.Migrations.CreateFontAssets do
  use Ecto.Migration

  def up do
    create table(:font_assets, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:font_id, references(:fonts, type: :uuid, column: :id, on_delete: :nilify_all))
      add(:asset_id, references(:asset, type: :uuid, column: :id, on_delete: :nilify_all))

      timestamps()
    end
  end

  def down do
    drop(table(:font_assets))
  end
end
