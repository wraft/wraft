defmodule WraftDoc.Repo.Migrations.UrUniqueIndex do
  use Ecto.Migration

  def change do
   create unique_index(:user_role, [:user_id, :role_id], name: :user_role_unique_index)
   create unique_index(:organisation_role, [:role_id, :organisation_id], name: :organisation_role_unique_index)
  end
end
