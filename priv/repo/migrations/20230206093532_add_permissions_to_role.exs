defmodule WraftDoc.Repo.Migrations.AddPermissionsToRole do
  use Ecto.Migration

  def change do
    alter table(:role) do
      add(:permissions, :jsonb)
    end
  end
end
