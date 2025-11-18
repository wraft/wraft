defmodule WraftDoc.Repo.Migrations.CreateWorkflows do
  use Ecto.Migration

  def change do
    create table(:workflows, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:name, :string, null: false)
      add(:description, :text)
      add(:is_active, :boolean, default: true, null: false)
      add(:config, :map, default: %{})

      add(:organisation_id, references(:organisation, type: :uuid, on_delete: :delete_all),
        null: false
      )

      add(:creator_id, references(:user, type: :uuid, on_delete: :nilify_all), null: false)
      timestamps(type: :utc_datetime)
    end

    create(index(:workflows, [:organisation_id]))
    create(index(:workflows, [:is_active]))
    create(unique_index(:workflows, [:name, :organisation_id], name: :workflows_name_org_unique))
  end
end
