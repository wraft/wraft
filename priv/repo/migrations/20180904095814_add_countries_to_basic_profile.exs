defmodule Starter.Repo.Migrations.AddCountriesToBasicProfile do
  use Ecto.Migration

  def change do
    alter table(:basic_profile) do
      add :countries_id, references(:countries)
    end
  end
end
