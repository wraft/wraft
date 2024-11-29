defmodule WraftDoc.Repo.Migrations.CreateFrameTableAndAssociateWithLayout do
  use Ecto.Migration

  def change do
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
  end
end
