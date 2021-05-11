defmodule WraftDoc.Repo.Migrations.AddRolesTable do
  use Ecto.Migration

  def change do
    create table(:role, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:name, :string, null: false)
      timestamps()
    end
  end
end
