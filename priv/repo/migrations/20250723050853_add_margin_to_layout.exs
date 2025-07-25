defmodule WraftDoc.Repo.Migrations.AddMarginToLayout do
  use Ecto.Migration

  def up do
    rename(table("layout"), to: table("layouts"))

    alter table(:layouts) do
      add(:margin, :map)
    end
  end

  def down do
    alter table(:layouts) do
      remove(:margin)
    end

    rename(table("layouts"), to: table("layout"))
  end
end
