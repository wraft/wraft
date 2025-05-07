defmodule WraftDoc.Repo.Migrations.AddFieldsToFrame do
  use Ecto.Migration

  def up do
    alter table(:frame) do
      add(:fields, {:array, :map}, default: [])
    end

    drop(table(:frame_field))
  end

  def down do
    alter table(:frame) do
      remove(:fields)
    end

    create table(:frame_field, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:frame_id, references(:frame, type: :uuid, on_delete: :nilify_all))
      add(:field_id, references(:field, type: :uuid, on_delete: :nilify_all))
    end
  end
end
