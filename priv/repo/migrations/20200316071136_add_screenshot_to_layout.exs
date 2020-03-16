defmodule WraftDoc.Repo.Migrations.AddScreenshotToLayout do
  use Ecto.Migration

  def up do
    alter table(:layout) do
      add(:screenshot, :string)
    end
  end

  def down do
    alter table(:layout) do
      remove(:screenshot)
    end
  end
end
