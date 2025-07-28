defmodule WraftDoc.Repo.Migrations.AddMarginToLayout do
  use Ecto.Migration

  def up do
    rename(table("layout"), to: table("layouts"))

    alter table(:layouts) do
      add(:margin, :map)
    end

    execute("""
    UPDATE layouts
    SET margin = '{"top": 2.5, "left": 2.5, "right": 2.5, "bottom": 2.5}'
    WHERE margin IS NULL
    """)
  end

  def down do
    alter table(:layouts) do
      remove(:margin)
    end

    rename(table("layouts"), to: table("layout"))
  end
end
