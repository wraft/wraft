defmodule WraftDoc.Repo.Migrations.AddFrameAsset do
  use Ecto.Migration

  def up do
    create table(:frame_asset, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:frame_id, references(:frame, type: :uuid, on_delete: :nilify_all))
      add(:asset_id, references(:asset, type: :uuid, on_delete: :nilify_all))

      timestamps()
    end

    alter table(:frame) do
      add(:type, :string)
      add(:description, :string)
      add(:thumbnail, :string)
      add(:wraft_json, :map)
    end
  end

  def down do
    drop(table(:frame_asset))

    alter table(:frame) do
      remove(:type)
      remove(:description)
      remove(:thumbnail)
      remove(:wraft_json)
    end
  end
end
