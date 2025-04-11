defmodule WraftDoc.Repo.Migrations.AlterTemplateAssetTableAddAsset do
  use Ecto.Migration

  def up do
    alter table(:template_asset) do
      add(:asset_id, references(:asset, type: :uuid, on_delete: :delete_all))
    end

    drop(table(:template_asset_asset))
  end

  def down do
    alter table(:template_asset) do
      remove(:asset_id)
    end

    create(table(:template_asset_asset, primary_key: false)) do
      add(:id, :uuid, primary_key: true)
      add(:template_asset_id, references(:template_asset, type: :uuid, on_delete: :nilify_all))
      add(:asset_id, references(:asset, type: :uuid, on_delete: :nilify_all))

      timestamps()
    end
  end
end
