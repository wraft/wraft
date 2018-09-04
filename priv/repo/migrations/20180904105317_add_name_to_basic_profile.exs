defmodule Starter.Repo.Migrations.AddNameToBasicProfile do
  use Ecto.Migration

  def change do
    alter table(:basic_profile) do
      add :firstname, :string, null: false
      add :lastname, :string, null: false
    end
  end
end
