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
  end

  def down do
    drop(table(:frame_mapping))
  end
end
