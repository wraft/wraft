defmodule WraftDoc.Repo.Migrations.AddPrefixFieldToContentTypeTable do
  use Ecto.Migration

  def up do
    alter table(:content_type) do
      add(:prefix, :string)
    end
  end

  def down do
    alter table(:content_type) do
      remove(:prefix)
    end
  end
end
