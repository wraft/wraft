defmodule ExStarter.Repo.Migrations.AddCountriesToBasicProfile do
  use Ecto.Migration

  def change do
    alter table(:basic_profile) do
      add(:country_id, references(:country))
    end
  end
end
