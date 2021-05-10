defmodule WraftDoc.Repo.Migrations.CreateCountries do
  use Ecto.Migration

  def change do
    create table(:country, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:country_name, :string)
      add(:country_code, :string)
      add(:calling_code, :string)
    end

    create(unique_index(:country, [:country_code]))
  end
end
