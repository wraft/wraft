defmodule WraftDoc.Repo.Migrations.ChangeOrganisationNameUniqueIndex do
  @moduledoc false
  use Ecto.Migration

  def change do
    drop(unique_index(:organisation, [:name], name: :organisation_unique_index))

    create(
      unique_index(:organisation, [:legal_name], name: :organisation_legal_name_unique_index)
    )
  end
end
