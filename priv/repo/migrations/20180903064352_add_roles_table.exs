defmodule ExStarter.Repo.Migrations.AddRolesTable do
  use Ecto.Migration

  def change do
    create table(:role) do
      add(:name, :string, null: false)
      timestamps()
    end
  end
end
