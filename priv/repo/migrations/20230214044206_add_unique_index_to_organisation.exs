defmodule WraftDoc.Repo.Migrations.AddUniqueIndexToOrganisation do
  use Ecto.Migration

  def change do
    alter table(:organisation) do
      add(:creator_id, references(:user, type: :uuid, column: :id, on_delete: :nilify_all))
    end

    create(unique_index(:organisation, [:name, :creator_id]))
  end
end
