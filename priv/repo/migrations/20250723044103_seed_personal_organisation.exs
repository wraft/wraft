defmodule WraftDoc.Repo.Migrations.SeedPersonalOrganisation do
  use Ecto.Migration

  def up, do: WraftDoc.SeedPersonalOrganisations.seed_all()

  def down, do: :ok
end
