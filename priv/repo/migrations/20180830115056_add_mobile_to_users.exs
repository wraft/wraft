defmodule ExStarter.Repo.Migrations.AddMobileToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:mobile, :string, null: false)
    end

    create(unique_index(:users, [:mobile]))
  end
end
