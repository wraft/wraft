defmodule WraftDoc.Repo.Migrations.AddOwnerToOrganisation do
  use Ecto.Migration

  def change do
    alter table(:organisation) do
      add(:owner_id, references(:user, type: :uuid))
    end

    execute("UPDATE organisation SET owner_id = creator_id")
  end

  def down do
    alter table(:organisation) do
      remove(:owner_id)
    end
  end
end
