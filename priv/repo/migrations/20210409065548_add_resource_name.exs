defmodule WraftDoc.Repo.Migrations.AddResourceName do
  use Ecto.Migration

  def change do
    alter table(:resource) do
      add(:name, :string)
    end
  end
end
