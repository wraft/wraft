defmodule WraftDoc.Repo.Migrations.CreateStateUsers do
  use Ecto.Migration

  def change do
    create table(:state_users, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:state_id, references(:state, type: :uuid, on_delete: :delete_all))
      add(:user_id, references(:user, type: :uuid, on_delete: :delete_all))

      timestamps()
    end

    create(unique_index(:state_users, [:state_id, :user_id]))
  end
end
