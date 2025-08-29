defmodule WraftDoc.Repo.Migrations.CreateInviteUsersRolesTable do
  use Ecto.Migration

  def up do
    create table(:invited_users_roles, primary_key: false) do
      add(:invited_user_id, references(:invited_user, on_delete: :delete_all, type: :uuid))
      add(:role_id, references(:role, on_delete: :delete_all, type: :uuid))
    end

    create(unique_index(:invited_users_roles, [:invited_user_id, :role_id]))
  end

  def down do
    drop(table(:invited_users_roles))
  end
end
