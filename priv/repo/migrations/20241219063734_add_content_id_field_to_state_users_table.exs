defmodule WraftDoc.Repo.Migrations.AddContentIdFieldToStateUsersTable do
  use Ecto.Migration

  def change do
    alter table(:state_users) do
      add(:content_id, references(:content, type: :uuid, on_delete: :delete_all))
    end
  end
end
