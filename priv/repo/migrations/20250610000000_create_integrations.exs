defmodule WraftDoc.Repo.Migrations.CreateIntegrations do
  use Ecto.Migration

  def change do
    create table(:integrations, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:provider, :string, null: false)
      add(:name, :string, null: false)
      add(:category, :string, null: false)
      add(:enabled, :boolean, default: false, null: false)
      add(:config, :binary, null: false)
      add(:events, {:array, :string}, default: [], null: false)
      add(:metadata, :map, default: %{}, null: false)

      add(:organisation_id, references(:organisation, on_delete: :delete_all, type: :binary_id),
        null: false
      )

      timestamps()
    end

    create(index(:integrations, [:organisation_id]))
    create(index(:integrations, [:category]))

    create(
      unique_index(:integrations, [:organisation_id, :provider],
        name: :organisation_provider_index
      )
    )
  end
end
