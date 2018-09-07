defmodule Starter.Repo.Migrations.CreateCountries do
  use Ecto.Migration

  def change do
    create table(:countries) do
      add :country_name, :string
      add :country_code, :string
      add :calling_code, :string
    end
    create unique_index(:countries, [:country_code])
  end
end
