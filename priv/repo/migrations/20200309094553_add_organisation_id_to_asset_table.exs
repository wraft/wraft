defmodule WraftDoc.Repo.Migrations.AddOrganisationIdToAssetTable do
  use Ecto.Migration

  def up do
    alter table(:asset) do
      add(:organisation_id, references(:organisation, on_delete: :nilify_all))
    end
  end

  def down do
    alter table(:asset) do
      remove(:organisation_id)
    end
  end
end
