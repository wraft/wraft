defmodule WraftDoc.Repo.Migrations.AddOnDeleteFunctionsToLayoutAsset do
  use Ecto.Migration

  def up do
    create(unique_index(:layout_asset, [:layout_id, :asset_id], name: :layout_asset_unique_index))
  end

  def down do
    drop(unique_index(:layout_asset, [:layout_id, :asset_id], name: :layout_asset_unique_index))
  end
end
