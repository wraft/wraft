defmodule WraftDoc.Repo.Migrations.CreateCounterTable do
  use Ecto.Migration

  def up do
    create table(:counter, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:subject, :string)
      add(:count, :integer)
      timestamps()
    end
  end

  def down do
    drop_if_exists(table(:counter))
  end
end
