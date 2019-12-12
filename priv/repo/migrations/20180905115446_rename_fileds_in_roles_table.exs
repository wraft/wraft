defmodule ExStarter.Repo.Migrations.RenameFiledsInRolesTable do
  use Ecto.Migration

  def change do
    alter table(:users) do
      remove(:roles_id)
      add(:role_id, references(:roles))
    end
  end
end
