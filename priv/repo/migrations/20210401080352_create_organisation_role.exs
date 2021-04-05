defmodule WraftDoc.Repo.Migrations.CreateOrganisationRole do
  use Ecto.Migration

  def change do
    create table(:organisation_role) do
      add :uuid, :uuid, null: false, autogenerate: true
      add :organisation_id, references(:organisation, on_delete: :delete_all)
      add :role_id, references(:role, on_delete: :delete_all)

      timestamps()
     end
  end
end
