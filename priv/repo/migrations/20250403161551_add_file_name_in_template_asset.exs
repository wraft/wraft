defmodule WraftDoc.Repo.Migrations.AddFileNameInTemplateAsset do
  use Ecto.Migration

  def up do
    alter table(:template_asset) do
      remove(:zip_file)
      add(:file_name, :string)
    end

    create(
      unique_index(:template_asset, [:file_name],
        where: "creator_id IS NULL AND organisation_id IS NULL",
        name: :unique_public_template_file_name
      )
    )
  end

  def down do
    alter table(:template_asset) do
      add(:zip_file, :string)
      remove(:file_name)
    end
  end
end
