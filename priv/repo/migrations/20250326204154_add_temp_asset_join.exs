defmodule WraftDoc.Repo.Migrations.AddTempAssetJoin do
  use Ecto.Migration

  def up do
    create table(:temp_asset, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:template_asset_id, references(:template_asset, type: :uuid, on_delete: :nilify_all))
      add(:asset_id, references(:asset, type: :uuid, on_delete: :nilify_all))

      timestamps()
    end
  end

  def down do
    drop(table(:temp_asset))
  end
end
