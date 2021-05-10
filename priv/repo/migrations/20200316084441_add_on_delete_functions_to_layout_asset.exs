defmodule WraftDoc.Repo.Migrations.AddOnDeleteFunctionsToLayoutAsset do
  use Ecto.Migration

  def up do
    drop(constraint(:layout_asset, "layout_asset_layout_id_fkey"))
    drop(constraint(:layout_asset, "layout_asset_asset_id_fkey"))

    create(unique_index(:layout_asset, [:layout_id, :asset_id], name: :layout_asset_unique_index))
  end

  def down do
    drop(constraint(:layout_asset, "layout_asset_layout_id_fkey"))
    drop(constraint(:layout_asset, "layout_asset_asset_id_fkey"))
    drop(unique_index(:layout_asset, [:layout_id, :asset_id], name: :layout_asset_unique_index))
  end
end
