defmodule WraftDoc.Repo.Migrations.CreateFrameTableAndAssociateWithLayout do
  use Ecto.Migration

  def up do
    create table(:frame, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:name, :string)
      add(:frame_file, :string)

      add(
        :organisation_id,
        references(:organisation, type: :uuid, column: :id, on_delete: :nilify_all)
      )

      add(:creator_id, references(:user, type: :uuid, column: :id, on_delete: :nothing))

      timestamps()
    end

    create(
      unique_index(:frame, [:name, :organisation_id], name: :frame_name_organisation_id_index)
    )

    alter table(:layout) do
      remove(:slug_file)

      add(:frame_id, references(:frame, type: :uuid, column: :id, on_delete: :nilify_all))
    end
  end

  def down do
    drop(constraint(:layout, :layout_frame_id_fkey))

    alter table(:layout) do
      add(:slug_file, :string)

      remove(:frame_id)
    end

    drop_if_exists(
      unique_index(:frame, [:name, :organisation_id], name: :frame_name_organisation_id_index)
    )

    drop(table(:frame))
  end
end
