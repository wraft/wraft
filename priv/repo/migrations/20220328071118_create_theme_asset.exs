defmodule WraftDoc.Repo.Migrations.CreateThemeAsset do
  use Ecto.Migration

  def change do
    create table(:theme_assets, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:theme_id, references(:theme, type: :uuid, column: :id, on_delete: :nilify_all))
      add(:asset_id, references(:asset, type: :uuid, column: :id, on_delete: :nilify_all))

      timestamps()
    end
  end
end
