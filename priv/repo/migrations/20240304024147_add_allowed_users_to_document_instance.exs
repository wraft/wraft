defmodule WraftDoc.Repo.Migrations.AddAllowedUsersToDocumentInstance do
  use Ecto.Migration

  def change do
    alter table(:content) do
      add(:allowed_users, {:array, :string}, null: false, default: [])
    end
  end
end
