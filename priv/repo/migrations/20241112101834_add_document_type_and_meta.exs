defmodule WraftDoc.Repo.Migrations.AddDocumentTypeAndMeta do
  use Ecto.Migration

  def change do
    alter table(:content) do
      add(:meta, :map)
    end

    alter table(:content_type) do
      add(:type, :string)
    end

    execute("UPDATE content_type SET type = 'document' WHERE type IS NULL")
  end
end
