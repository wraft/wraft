defmodule WraftDoc.Repo.Migrations.AddDescriptionTemplateAssetTable do
  use Ecto.Migration

  def change do
    alter table(:template_asset) do
      add(:description, :string)
      add(:zip_file_size, :string)
      add(:is_imported, :boolean)
    end
  end
end
