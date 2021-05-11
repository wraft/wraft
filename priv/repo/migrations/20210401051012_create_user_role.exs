defmodule WraftDoc.Repo.Migrations.CreateUserRole do
  use Ecto.Migration

  def up do
    create table(:user_role, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:user_id, references(:user, type: :uuid, column: :id, on_delete: :nilify_all))
      add(:role_id, references(:role, type: :uuid, column: :id, on_delete: :nilify_all))
      timestamps()
    end
  end

  def down do
    drop(table(:user_role))
  end
end
