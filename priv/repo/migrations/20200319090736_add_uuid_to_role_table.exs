defmodule WraftDoc.Repo.Migrations.AddUuidToRoleTable do
  use Ecto.Migration

  def up do
    alter table(:role) do
      add(:uuid, :uuid)
    end
  end

  def down do
    alter table(:role) do
      remove(:uuid)
    end
  end
end
