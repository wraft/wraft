defmodule WraftDoc.Repo.Migrations.CreateWorkflowCredentials do
  use Ecto.Migration

  def change do
    create table(:workflow_credentials, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:name, :string, null: false)
      add(:adaptor_type, :string, null: false)
      add(:credentials_encrypted, :binary, null: false)
      add(:metadata, :map, default: %{})

      add(:organisation_id, references(:organisation, type: :uuid, on_delete: :delete_all),
        null: false
      )

      add(:creator_id, references(:user, type: :uuid, on_delete: :nilify_all), null: false)
      timestamps(type: :utc_datetime)
    end

    create(index(:workflow_credentials, [:organisation_id]))
    create(index(:workflow_credentials, [:adaptor_type]))

    create(
      unique_index(:workflow_credentials, [:name, :organisation_id],
        name: :workflow_credentials_name_org_unique
      )
    )
  end
end
