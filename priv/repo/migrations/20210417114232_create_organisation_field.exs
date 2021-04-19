defmodule WraftDoc.Repo.Migrations.CreateOrganisationField do
  use Ecto.Migration

  def change do
    create table(:organisation_field) do
      add(:uuid, :uuid, null: false, autogenerate: true)
      add(:name, :string)
      add(:meta, :jsonb)
      add(:description, :string)
      add(:field_type_id, references(:field_type, on_delete: :nilify_all))
      add(:organisation_id, references(:organisation, on_delete: :nilify_all))
      add(:creator_id, references(:user, on_delete: :nilify_all))
      timestamps()
    end
  end
end
