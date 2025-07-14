defmodule WraftDoc.Repo.Migrations.AddEvents do
  use Ecto.Migration

  def up do
    create table(:events, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:name, :string, null: false)

      timestamps()
    end

    create(index(:events, [:name]))
  end

  def down do
    drop(table(:events))
  end
end
