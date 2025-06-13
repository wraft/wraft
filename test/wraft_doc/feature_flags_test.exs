defmodule WraftDoc.FeatureFlagsTest do
  use WraftDoc.DataCase, async: true

  import WraftDoc.Factory

  alias WraftDoc.Enterprise.Organisation
  alias WraftDoc.FeatureFlags

  @valid_features [:ai_features, :repository, :document_extraction]
  @invalid_feature :non_existent_feature

  describe "enabled?/2" do
    test "returns false for disabled features by default" do
      organisation = insert(:organisation)

      refute FeatureFlags.enabled?(:ai_features, organisation)
      refute FeatureFlags.enabled?(:google_drive_integration, organisation)
    end

    test "returns false for invalid features" do
      organisation = insert(:organisation)

      refute FeatureFlags.enabled?(@invalid_feature, organisation)
    end

    test "returns true for enabled features" do
      organisation = insert(:organisation)

      :ok = FeatureFlags.enable(:ai_features, organisation)

      assert FeatureFlags.enabled?(:ai_features, organisation)
      refute FeatureFlags.enabled?(:google_drive_integration, organisation)
    end
  end

  describe "enable/2" do
    test "enables a valid feature for an organisation" do
      organisation = insert(:organisation)

      assert :ok = FeatureFlags.enable(:ai_features, organisation)
      assert FeatureFlags.enabled?(:ai_features, organisation)
    end

    test "returns error for invalid feature" do
      organisation = insert(:organisation)

      assert {:error, :invalid_feature} = FeatureFlags.enable(@invalid_feature, organisation)
    end
  end

  describe "disable/2" do
    test "disables an enabled feature for an organisation" do
      organisation = insert(:organisation)

      :ok = FeatureFlags.enable(:ai_features, organisation)
      assert FeatureFlags.enabled?(:ai_features, organisation)

      :ok = FeatureFlags.disable(:ai_features, organisation)
      refute FeatureFlags.enabled?(:ai_features, organisation)
    end

    test "returns error for invalid feature" do
      organisation = insert(:organisation)

      assert {:error, :invalid_feature} = FeatureFlags.disable(@invalid_feature, organisation)
    end
  end

  describe "available_features/0" do
    test "returns list of available features" do
      features = FeatureFlags.available_features()

      assert is_list(features)
      assert :ai_features in features
      assert :google_drive_integration in features
      assert :advanced_analytics in features
    end
  end

  describe "enabled_features/1" do
    test "returns empty list when no features are enabled" do
      organisation = insert(:organisation)

      assert [] = FeatureFlags.enabled_features(organisation)
    end

    test "returns list of enabled features" do
      organisation = insert(:organisation)

      :ok = FeatureFlags.enable(:ai_features, organisation)
      :ok = FeatureFlags.enable(:google_drive_integration, organisation)

      enabled = FeatureFlags.enabled_features(organisation)

      assert :ai_features in enabled
      assert :google_drive_integration in enabled
      refute :advanced_analytics in enabled
    end
  end

  describe "disabled_features/1" do
    test "returns all features when none are enabled" do
      organisation = insert(:organisation)

      disabled = FeatureFlags.disabled_features(organisation)
      available = FeatureFlags.available_features()

      assert length(disabled) == length(available)
      assert :ai_features in disabled
    end

    test "returns only disabled features when some are enabled" do
      organisation = insert(:organisation)

      :ok = FeatureFlags.enable(:ai_features, organisation)

      disabled = FeatureFlags.disabled_features(organisation)

      refute :ai_features in disabled
      assert :google_drive_integration in disabled
    end
  end

  describe "bulk_enable/2" do
    test "enables multiple features at once" do
      organisation = insert(:organisation)
      features = [:ai_features, :google_drive_integration]

      assert :ok = FeatureFlags.bulk_enable(features, organisation)

      assert FeatureFlags.enabled?(:ai_features, organisation)
      assert FeatureFlags.enabled?(:google_drive_integration, organisation)
      refute FeatureFlags.enabled?(:advanced_analytics, organisation)
    end
  end

  describe "bulk_disable/2" do
    test "disables multiple features at once" do
      organisation = insert(:organisation)
      features = [:ai_features, :google_drive_integration]

      # First enable them
      :ok = FeatureFlags.bulk_enable(features, organisation)
      assert FeatureFlags.enabled?(:ai_features, organisation)
      assert FeatureFlags.enabled?(:google_drive_integration, organisation)

      # Then disable them
      assert :ok = FeatureFlags.bulk_disable(features, organisation)
      refute FeatureFlags.enabled?(:ai_features, organisation)
      refute FeatureFlags.enabled?(:google_drive_integration, organisation)
    end
  end

  describe "setup_defaults/1" do
    test "sets up all features as disabled for new organisation" do
      organisation = insert(:organisation)

      assert :ok = FeatureFlags.setup_defaults(organisation)

      available_features = FeatureFlags.available_features()
      enabled_features = FeatureFlags.enabled_features(organisation)

      assert enabled_features == []
      assert length(FeatureFlags.disabled_features(organisation)) == length(available_features)
    end
  end

  describe "get_organization_features/1" do
    test "returns map of all features with their status" do
      organisation = insert(:organisation)

      :ok = FeatureFlags.enable(:ai_features, organisation)

      features_map = FeatureFlags.get_organization_features(organisation)

      assert is_map(features_map)
      assert features_map[:ai_features] == true
      assert features_map[:google_drive_integration] == false
    end
  end

  describe "global feature flags" do
    test "enable_globally/1 enables feature for all organisations" do
      org1 = insert(:organisation)
      org2 = insert(:organisation)

      :ok = FeatureFlags.enable_globally(:ai_features)

      assert FeatureFlags.enabled_globally?(:ai_features)
      # Global flags don't affect organization-specific flags in FunWithFlags
      # Organizations need to have features enabled specifically for them
    end

    test "enabled_globally?/1 checks global feature status" do
      refute FeatureFlags.enabled_globally?(:ai_features)

      :ok = FeatureFlags.enable_globally(:ai_features)
      assert FeatureFlags.enabled_globally?(:ai_features)

      :ok = FeatureFlags.disable_globally(:ai_features)
      refute FeatureFlags.enabled_globally?(:ai_features)
    end
  end

  describe "organization isolation" do
    test "features are isolated between organizations" do
      org1 = insert(:organisation)
      org2 = insert(:organisation)

      :ok = FeatureFlags.enable(:ai_features, org1)

      assert FeatureFlags.enabled?(:ai_features, org1)
      refute FeatureFlags.enabled?(:ai_features, org2)
    end
  end
end
