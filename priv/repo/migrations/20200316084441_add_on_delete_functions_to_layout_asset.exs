defmodule WraftDoc.Repo.Migrations.AddOnDeleteFunctionsToLayoutAsset do
  use Ecto.Migration

  def up do
    drop(constraint(:layout_asset, "layout_asset_layout_id_fkey"))
    drop(constraint(:layout_asset, "layout_asset_asset_id_fkey"))

    alter table(:layout_asset) do
      modify(:layout_id, references(:layout, on_delete: :delete_all))
      modify(:asset_id, references(:asset, on_delete: :delete_all))
    end

    create(unique_index(:layout_asset, [:layout_id, :asset_id], name: :layout_asset_unique_index))
  end

  def down do
    drop(constraint(:layout_asset, "layout_asset_layout_id_fkey"))
    drop(constraint(:layout_asset, "layout_asset_asset_id_fkey"))
    drop(unique_index(:layout_asset, [:layout_id, :asset_id], name: :layout_asset_unique_index))

    alter table(:layout_asset) do
      modify(:layout_id, references(:layout))
      modify(:asset_id, references(:asset))
    end
  end
end
