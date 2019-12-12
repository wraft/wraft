defmodule ExStarter.Repo.Migrations.AddRolesTable do
  use Ecto.Migration

  def change do
    create table(:roles) do
      add(:name, :string, null: false)
      add(:admin, :boolean, default: false, null: false)
      timestamps()
    end
  end
end
