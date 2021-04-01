defmodule WraftDoc.Repo.Migrations.CreateUserRole do
  use Ecto.Migration

  def change do
   create table(:user_role) do
    add :user_id, references(:user,on_delete: :delete_all)
    add :role_id, references(:role, on_delete: :delete_all)
    timestamps()
   end
  end
end
