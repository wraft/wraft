defmodule WraftDoc.Repo.Migrations.AddFrameFields do
  use Ecto.Migration

  def up do
    create table(:frame_field, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:frame_id, references(:frame, type: :uuid, on_delete: :nilify_all))
      add(:field_id, references(:field, type: :uuid, on_delete: :nilify_all))

      timestamps()
    end
  end

  def down do
    drop(table(:frame_field))
  end
end
