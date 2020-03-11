defmodule WraftDoc.Repo.Migrations.AddSlugFilesToLayout do
  use Ecto.Migration

  def up do
    alter table(:layout) do
      add(:slug_file, :string)
    end
  end

  def down do
    alter table(:layout) do
      remove(:slug_file)
    end
  end
end
