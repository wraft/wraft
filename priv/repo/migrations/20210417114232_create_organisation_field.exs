defmodule WraftDoc.Repo.Migrations.CreateOrganisationField do
  use Ecto.Migration

  def change do
    create table(:organisation_field, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:name, :string)
      add(:meta, :jsonb)
      add(:description, :string)

      add(
        :field_type_id,
        references(:field_type, type: :uuid, coloumn: :id, on_delete: :nilify_all)
      )

      add(
        :organisation_id,
        references(:organisation, type: :uuid, coloumn: :id, on_delete: :nilify_all)
      )

      add(:creator_id, references(:user, type: :uuid, coloumn: :id, on_delete: :nilify_all))
      timestamps()
    end
  end
end
