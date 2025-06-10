defmodule WraftDoc.Repo.Migrations.CreateRepositories do
  use Ecto.Migration

  def change do
    create table(:repositories, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:name, :string)
      add(:description, :text)
      add(:storage_limit, :bigint)
      add(:current_storage_used, :bigint)
      add(:item_count, :integer)
      add(:status, :string)
      add(:organisation_id, references(:organisation, on_delete: :nothing, type: :uuid))
      add(:creator_id, references(:user, on_delete: :nothing, type: :uuid))

      timestamps()
    end

    create(index(:repositories, [:organisation_id]))
    create(index(:repositories, [:creator_id]))
  end
end
