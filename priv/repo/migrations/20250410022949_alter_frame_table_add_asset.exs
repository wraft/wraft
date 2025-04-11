defmodule WraftDoc.Repo.Migrations.AlterFrameTableAddAsset do
  use Ecto.Migration

  def up do
    alter table(:frame) do
      add(:asset_id, references(:asset, type: :uuid, on_delete: :nilify_all))
    end

    drop(table(:frame_asset))
  end

  def down do
    alter table(:frame) do
      remove(:asset_id)
    end

    create table(:frame_asset, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:frame_id, references(:frame, type: :uuid, on_delete: :nilify_all))
      add(:asset_id, references(:asset, type: :uuid, on_delete: :nilify_all))

      timestamps()
    end

    drop(constraint(:frame_asset, :frame_asset_frame_id_fkey))
  end
end
