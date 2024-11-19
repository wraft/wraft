defmodule WraftDoc.Repo.Migrations.AddFileEntiresToTemplateAsset do
  use Ecto.Migration

  def up do
    alter table(:template_asset) do
      add(:file_entries, {:array, :string}, default: [])
    end
  end

  def down do
    alter table(:template_asset) do
      remove(:file_entries)
    end
  end
end
