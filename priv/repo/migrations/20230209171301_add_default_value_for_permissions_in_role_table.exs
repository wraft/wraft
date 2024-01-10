defmodule WraftDoc.Repo.Migrations.AddDefaultValueForPermissionsInRoleTable do
  use Ecto.Migration

  def change do
    alter table(:role) do
      remove(:permissions)
      add(:permissions, {:array, :string}, null: false, default: [])
    end
  end
end
