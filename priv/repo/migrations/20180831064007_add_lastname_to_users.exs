defmodule ExStarter.Repo.Migrations.AddLastnameToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:lastname, :string, null: false)
    end

    rename(table(:users), :name, to: :firstname)
  end
end
