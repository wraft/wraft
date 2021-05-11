defmodule WraftDoc.Repo.Migrations.CreateOrganisationRole do
  use Ecto.Migration

  def change do
    create table(:organisation_role, primary_key: false) do
      add(:id, :uuid, primary_key: true)

      add(
        :organisation_id,
        references(:organisation, type: :uuid, column: :id, on_delete: :nilify_all)
      )

      add(:role_id, references(:role, type: :uuid, column: :id, on_delete: :nilify_all))

      timestamps()
    end
  end
end
