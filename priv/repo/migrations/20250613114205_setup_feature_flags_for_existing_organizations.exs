defmodule WraftDoc.Repo.Migrations.SetupFeatureFlagsForExistingOrganizations do
  use Ecto.Migration

  alias WraftDoc.FeatureFlags
  alias WraftDoc.Repo

  def up do
    unless self_hosted?() do
      organizations = Repo.query!("SELECT id FROM organisation")

      Enum.each(organizations.rows, fn [org_id] ->
        organization = %{id: org_id}
        FeatureFlags.setup_defaults(organization)
      end)
    end
  end

  def down do
    unless self_hosted?() do
      organizations = Repo.query!("SELECT id FROM organisation")

      Enum.each(organizations.rows, fn [org_id] ->
        organization = %{id: org_id}
        available_features = FeatureFlags.available_features()
        FeatureFlags.bulk_disable(available_features, organization)
      end)
    end
  end

  defp self_hosted? do
    Application.get_env(:wraft_doc, :deployment)[:is_self_hosted] == true
  end
end
