defmodule WraftDoc.Repo.Migrations.AddFrameMapping do
  use Ecto.Migration

  def up do
    create table(:frame_mapping, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:mapping, :map)
      add(:frame_id, references(:frame, type: :uuid, on_delete: :nilify_all))
      add(:content_type_id, references(:content_type, type: :uuid, on_delete: :nilify_all))

      timestamps()
    end

    create(
      unique_index(:frame_mapping, [:frame_id, :content_type_id],
        name: :frame_content_type_unique_index
      )
    )

    drop(constraint(:frame_asset, :frame_asset_frame_id_fkey))
    drop(constraint(:frame_asset, :frame_asset_asset_id_fkey))

    alter table(:frame_asset) do
      modify(:frame_id, references(:frame, type: :uuid, on_delete: :delete_all))
      modify(:asset_id, references(:asset, type: :uuid, on_delete: :delete_all))
    end
  end

  def down do
    drop(constraint(:frame_asset, :frame_asset_frame_id_fkey))
    drop(constraint(:frame_asset, :frame_asset_asset_id_fkey))

    alter table(:frame_asset) do
      modify(:frame_id, references(:frame, type: :uuid, on_delete: :nilify_all))
      modify(:asset_id, references(:asset, type: :uuid, on_delete: :nilify_all))
    end

    drop(table(:frame_mapping))
  end
end
