defmodule WraftDoc.Repo.Migrations.AddRoleToUsers do
  use Ecto.Migration

  def change do
    alter table(:user) do
      add(:role_id, references(:role))
    end
  end
end
