defmodule WraftDoc.Repo.Migrations.AddDeleteAtToUsersOrganisation do
  use Ecto.Migration

  def change do
    alter table(:users_organisations) do
      add(:deleted_at, :naive_datetime, null: true)
    end
  end
end
