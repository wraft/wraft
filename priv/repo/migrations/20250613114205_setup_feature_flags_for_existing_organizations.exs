defmodule WraftDoc.Repo.Migrations.SetupFeatureFlagsForExistingOrganizations do
  use Ecto.Migration

  alias WraftDoc.Enterprise.Organisation
  alias WraftDoc.FeatureFlags
  alias WraftDoc.Repo

  def up do
    organizations = Repo.all(Organisation)

    Enum.each(organizations, fn organization ->
      FeatureFlags.setup_defaults(organization)
    end)
  end

  def down do
    organizations = Repo.all(Organisation)

    Enum.each(organizations, fn organization ->
      available_features = FeatureFlags.available_features()
      FeatureFlags.bulk_disable(available_features, organization)
    end)
  end
end
