defmodule WraftDoc.Repo.Migrations.AddContentIdFieldToStateUsersTable do
  use Ecto.Migration

  def change do
    alter table(:state_users) do
      add(:content_id, references(:content, type: :uuid, on_delete: :delete_all))
    end

    # Drop the old index if it exists
    drop_if_exists(index(:state_users, [:state_id, :user_id]))

    # Create the first unique index with content_id condition
    create(
      unique_index(:state_users, [:state_id, :user_id, :content_id],
        where: "content_id IS NOT NULL"
      )
    )

    # Create the second unique index where content_id is NULL
    create(
      unique_index(:state_users, [:state_id, :user_id],
        name: :state_users_state_id_user_id_index,
        where: "content_id IS NULL"
      )
    )
  end
end
