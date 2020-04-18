defmodule WraftDoc.Repo.Migrations.CreateCounterTable do
  use Ecto.Migration

  def up do
    create table(:counter) do
      add(:subject, :string)
      add(:count, :integer)
    end
  end

  def down do
    drop_if_exists(table(:counter))
  end
end
