defmodule WraftDoc.Repo.Migrations.AddTemplateAssetAssetJoin do
  use Ecto.Migration

  def up do
    create table(:template_asset_asset, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:template_asset_id, references(:template_asset, type: :uuid, on_delete: :nilify_all))
      add(:asset_id, references(:asset, type: :uuid, on_delete: :nilify_all))

      timestamps()
    end
  end

  def down do
    drop(table(:template_asset_asset))
  end
end
