defmodule WraftDoc.Repo.Migrations.AddWraftJsonToTemplateAsset do
  use Ecto.Migration

  def change do
    alter table(:template_asset) do
      add(:wraft_json, :map)
    end
  end
end
