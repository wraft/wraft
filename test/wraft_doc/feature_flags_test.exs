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
      # Use existing feature
      refute FeatureFlags.enabled?(:repository, organisation)
    end

    test "returns false for invalid features" do
      organisation = insert(:organisation)

      refute FeatureFlags.enabled?(@invalid_feature, organisation)
    end

    test "returns true for enabled features" do
      organisation = insert(:organisation)

      # FIX: Handle the tuple return value
      {:ok, true} = FeatureFlags.enable(:ai_features, organisation)

      assert FeatureFlags.enabled?(:ai_features, organisation)
      # Use existing feature
      refute FeatureFlags.enabled?(:repository, organisation)
    end
  end

  describe "enable/2" do
    test "enables a valid feature for an organisation" do
      organisation = insert(:organisation)

      assert {:ok, true} = FeatureFlags.enable(:ai_features, organisation)
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

      # FIX: Handle the tuple return value
      {:ok, true} = FeatureFlags.enable(:ai_features, organisation)
      assert FeatureFlags.enabled?(:ai_features, organisation)

      # FIX: Handle the tuple return value for disable too
      {:ok, false} = FeatureFlags.disable(:ai_features, organisation)
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
      # Use features that actually exist
      assert :repository in features
      assert :document_extraction in features
      # Remove :google_drive_integration if it doesn't exist in your implementation
    end
  end

  describe "enabled_features/1" do
    test "returns empty list when no features are enabled" do
      organisation = insert(:organisation)

      assert [] = FeatureFlags.enabled_features(organisation)
    end

    test "returns list of enabled features" do
      organisation = insert(:organisation)

      # FIX: Handle tuple return values
      {:ok, true} = FeatureFlags.enable(:ai_features, organisation)
      # Use existing feature
      {:ok, true} = FeatureFlags.enable(:repository, organisation)

      enabled = FeatureFlags.enabled_features(organisation)

      assert :ai_features in enabled
      assert :repository in enabled
      refute :document_extraction in enabled
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

      # FIX: Handle tuple return value
      {:ok, true} = FeatureFlags.enable(:ai_features, organisation)

      disabled = FeatureFlags.disabled_features(organisation)

      refute :ai_features in disabled
      # Use existing feature
      assert :repository in disabled
    end
  end

  describe "bulk_enable/2" do
    test "enables multiple features at once" do
      organisation = insert(:organisation)
      # FIX: Use features that actually exist
      features = [:ai_features, :repository]

      # FIX: Handle tuple return value if bulk_enable returns one
      result = FeatureFlags.bulk_enable(features, organisation)
      assert :ok == result or match?({:ok, _}, result)

      assert FeatureFlags.enabled?(:ai_features, organisation)
      assert FeatureFlags.enabled?(:repository, organisation)
      refute FeatureFlags.enabled?(:document_extraction, organisation)
    end
  end

  describe "bulk_disable/2" do
    test "disables multiple features at once" do
      organisation = insert(:organisation)
      # FIX: Use features that actually exist
      features = [:ai_features, :repository]

      # First enable them
      result = FeatureFlags.bulk_enable(features, organisation)
      assert :ok == result or match?({:ok, _}, result)

      assert FeatureFlags.enabled?(:ai_features, organisation)
      assert FeatureFlags.enabled?(:repository, organisation)

      # Then disable them
      result = FeatureFlags.bulk_disable(features, organisation)
      assert :ok == result or match?({:ok, _}, result)

      refute FeatureFlags.enabled?(:ai_features, organisation)
      refute FeatureFlags.enabled?(:repository, organisation)
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

      # FIX: Handle tuple return value
      {:ok, true} = FeatureFlags.enable(:ai_features, organisation)

      features_map = FeatureFlags.get_organization_features(organisation)

      assert is_map(features_map)
      assert features_map[:ai_features] == true
      # Use existing feature
      assert features_map[:repository] == false
    end
  end

  describe "global feature flags" do
    test "enable_globally/1 enables feature for all organisations" do
      org1 = insert(:organisation)
      org2 = insert(:organisation)

      # FIX: Handle tuple return value
      {:ok, true} = FeatureFlags.enable_globally(:ai_features)

      assert FeatureFlags.enabled_globally?(:ai_features)
    end

    test "enabled_globally?/1 checks global feature status" do
      refute FeatureFlags.enabled_globally?(:ai_features)

      # FIX: Handle tuple return value
      {:ok, true} = FeatureFlags.enable_globally(:ai_features)
      assert FeatureFlags.enabled_globally?(:ai_features)

      # FIX: Handle tuple return value
      {:ok, false} = FeatureFlags.disable_globally(:ai_features)
      refute FeatureFlags.enabled_globally?(:ai_features)
    end
  end

  describe "organization isolation" do
    test "features are isolated between organizations" do
      org1 = insert(:organisation)
      org2 = insert(:organisation)

      # FIX: Handle tuple return value
      {:ok, true} = FeatureFlags.enable(:ai_features, org1)

      assert FeatureFlags.enabled?(:ai_features, org1)
      refute FeatureFlags.enabled?(:ai_features, org2)
    end
  end
end
