defmodule WraftDoc.Repo.Migrations.AddOrganisationUrlField do
  use Ecto.Migration

  def change do
    alter table(:organisation) do
      add(:url, :string)
    end
  end
end
