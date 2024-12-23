defmodule WraftDoc.Repo.Migrations.AddContentIdFieldToStateUsersTable do
  use Ecto.Migration

  def change do
    alter table(:state_users) do
      add(:content_id, references(:content, type: :uuid, on_delete: :delete_all))
    end

    drop(unique_index(:state_users, [:state_id, :user_id]))

    create(
      unique_index(:state_users, [:state_id, :content_id, :user_id],
        where: "content_id IS NOT NULL"
      )
    )
  end
end
