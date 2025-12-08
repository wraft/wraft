defmodule WraftDoc.Repo.Migrations.UpdateContentTypeTableUpdatePrefix do
  use Ecto.Migration

  def up do
    create(
      unique_index(:content_type, [:organisation_id, :prefix], name: :unique_org_prefix_index)
    )
  end

  def down do
    drop(index(:content_type, [:organisation_id, :prefix], name: :unique_org_prefix_index))
  end
end
