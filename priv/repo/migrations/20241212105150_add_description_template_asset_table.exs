defmodule WraftDoc.Repo.Migrations.AddDescriptionTemplateAssetTable do
  use Ecto.Migration

  def change do
    alter table(:template_asset) do
      add(:description, :string)
    end
  end
end
