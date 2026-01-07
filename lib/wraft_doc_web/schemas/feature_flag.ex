defmodule WraftDocWeb.Schemas.FeatureFlag do
  @moduledoc """
  Schema for FeatureFlag request and response
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

  defmodule FeatureFlag do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Feature Flag",
      description: "A feature flag status",
      type: :object,
      properties: %{
        feature: %Schema{type: :string, description: "Feature name"},
        enabled: %Schema{type: :boolean, description: "Whether the feature is enabled"}
      },
      required: [:feature, :enabled],
      example: %{
        feature: "ai_features",
        enabled: true
      }
    })
  end

  defmodule FeatureFlagsList do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Feature Flags List",
      description: "List of feature flags and their status",
      type: :object,
      properties: %{
        features: %Schema{
          type: :object,
          description: "Map of feature names to their enabled status"
        },
        available_features: %Schema{
          type: :array,
          description: "List of all available features",
          items: %Schema{type: :string}
        }
      },
      example: %{
        features: %{
          ai_features: false,
          google_drive_integration: false,
          advanced_analytics: true
        },
        available_features: ["ai_features", "google_drive_integration", "advanced_analytics"]
      }
    })
  end

  defmodule FeatureFlagUpdateRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Feature Flag Update Request",
      description: "Request to update a feature flag",
      type: :object,
      properties: %{
        enabled: %Schema{type: :boolean, description: "Whether to enable or disable the feature"}
      },
      required: [:enabled],
      example: %{
        enabled: true
      }
    })
  end

  defmodule BulkFeatureFlagUpdateRequest do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Bulk Feature Flag Update Request",
      description: "Request to update multiple feature flags",
      type: :object,
      properties: %{
        features: %Schema{
          type: :object,
          description: "Map of feature names to their enabled status",
          additionalProperties: %Schema{type: :boolean}
        }
      },
      required: [:features],
      example: %{
        features: %{
          "ai_features" => true,
          "google_drive_integration" => false,
          "advanced_analytics" => true
        }
      }
    })
  end

  defmodule BulkFeatureFlagUpdateResponse do
    @moduledoc false
    OpenApiSpex.schema(%{
      title: "Bulk Feature Flag Update Response",
      description: "Response for bulk feature flag update",
      type: :object,
      properties: %{
        successful: %Schema{
          type: :array,
          description: "List of successfully updated features",
          items: %Schema{type: :string}
        },
        failed: %Schema{
          type: :object,
          description: "Map of failed features to error messages"
        }
      },
      example: %{
        successful: ["ai_features", "advanced_analytics"],
        failed: %{
          "invalid_feature" => "Feature not available"
        }
      }
    })
  end
end
