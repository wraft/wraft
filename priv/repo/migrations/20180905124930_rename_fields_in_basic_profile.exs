defmodule Starter.Repo.Migrations.RenameFieldsInBasicProfile do
  use Ecto.Migration

  def change do
    alter table(:basic_profile) do
      remove :countries_id
      add :country_id, references(:countries)
    end
  end
end
