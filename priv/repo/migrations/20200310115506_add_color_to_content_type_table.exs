defmodule WraftDoc.Repo.Migrations.AddColorToContentTypeTable do
  use Ecto.Migration

  def up do
    alter table(:content_type) do
      add(:color, :string)
    end
  end

  def down do
    alter table(:content_type) do
      remove(:color)
    end
  end
end
