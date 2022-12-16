defmodule WraftDoc.Repo.Migrations.CreateUsersOrganisationsTable do
  @moduledoc false
  use Ecto.Migration

  def change do
    create table(:users_organisations, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:organisation_id, references(:organisation, type: :uuid, on_delete: :delete_all))
      add(:user_id, references(:user, type: :uuid, on_delete: :delete_all))

      timestamps()
    end

    create(unique_index(:users_organisations, [:organisation_id, :user_id]))
  end
end
