defmodule WraftDoc.Repo.Migrations.AddLayoutOrganisationUniqueIndex do
  use Ecto.Migration

  def up do
    drop_if_exists(unique_index(:layout, :name, name: :layout_name_unique_index))

    create(
      unique_index(:layout, [:name, :organisation_id], name: :layout_organisation_unique_index)
    )
  end

  def down do
    drop_if_exists(
      unique_index(:layout, [:name, :organisation_id], name: :layout_organisation_unique_index)
    )

    create(unique_index(:layout, :name, name: :layout_name_unique_index))
  end
end
