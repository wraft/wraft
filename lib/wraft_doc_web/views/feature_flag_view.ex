defmodule WraftDocWeb.Api.V1.FeatureFlagView do
  use WraftDocWeb, :view

  def render("index.json", %{
        features: features,
        available_features: available_features,
        organization: organization
      }) do
    %{
      organization_id: organization.id,
      organization_name: organization.name,
      features: features,
      available_features: available_features
    }
  end

  def render("show.json", %{feature: feature, enabled: enabled, organization: organization}) do
    %{
      organization_id: organization.id,
      organization_name: organization.name,
      feature: feature,
      enabled: enabled
    }
  end

  def render("update.json", %{feature: feature, enabled: enabled, organization: organization}) do
    %{
      organization_id: organization.id,
      organization_name: organization.name,
      feature: feature,
      enabled: enabled,
      message: "Feature flag updated successfully"
    }
  end

  def render("bulk_update.json", %{
        successful: successful,
        failed: failed,
        organization: organization
      }) do
    %{
      organization_id: organization.id,
      organization_name: organization.name,
      successful_updates: successful,
      failed_updates: failed,
      message: "Bulk update completed"
    }
  end
end
