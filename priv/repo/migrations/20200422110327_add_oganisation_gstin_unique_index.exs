defmodule WraftDoc.Repo.Migrations.AddOganisationGstinUniqueIndex do
  use Ecto.Migration

  def up do
    create(unique_index(:organisation, [:gstin], name: :organisation_gstin_unique_index))
  end

  def down do
    drop(index(:organisation, [:gstin], name: :organisation_gstin_unique_index))
  end
end
