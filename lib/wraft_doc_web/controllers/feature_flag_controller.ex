defmodule WraftDocWeb.Api.V1.FeatureFlagController do
  @moduledoc """
  Controller for managing organization-based feature flags.
  """
  use WraftDocWeb, :controller
  use PhoenixSwagger

  plug WraftDocWeb.Plug.Authorized,
    index: "organisation:show",
    show: "organisation:show",
    update: "organisation:manage",
    bulk_update: "organisation:manage"

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.Enterprise
  alias WraftDoc.FeatureFlags

  def swagger_definitions do
    %{
      FeatureFlag:
        swagger_schema do
          title("Feature Flag")
          description("A feature flag status")

          properties do
            feature(:string, "Feature name", required: true)
            enabled(:boolean, "Whether the feature is enabled", required: true)
          end

          example(%{
            feature: "ai_features",
            enabled: true
          })
        end,
      FeatureFlagsList:
        swagger_schema do
          title("Feature Flags List")
          description("List of feature flags and their status")

          properties do
            features(:object, "Map of feature names to their enabled status")
            available_features(:array, "List of all available features")
          end

          example(%{
            features: %{
              ai_features: false,
              google_drive_integration: false,
              advanced_analytics: true
            },
            available_features: ["ai_features", "google_drive_integration", "advanced_analytics"]
          })
        end
    }
  end

  @doc """
  List available features and their status for the current organization.
  """
  swagger_path :index do
    get("/organisations/features")
    summary("List organization feature flags")
    description("Get all feature flags and their status for the current organization")
    response(200, "OK", Schema.ref(:FeatureFlagsList))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  def index(conn, _params) do
    current_user = conn.assigns.current_user
    organization = Enterprise.get_organisation(current_user.current_org_id)

    features = FeatureFlags.get_organization_features(organization)
    available_features = FeatureFlags.available_features()

    render(conn, "index.json", %{
      features: features,
      available_features: available_features,
      organization: organization
    })
  end

  @doc """
  Show specific feature status for the current organization.
  """
  swagger_path :show do
    get("/organisations/features/{feature}")
    summary("Get specific feature flag")
    description("Get the status of a specific feature flag for the current organization")

    parameters do
      feature(:path, :string, "Feature name", required: true)
    end

    response(200, "OK", Schema.ref(:FeatureFlag))
    response(404, "Not Found", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
  end

  def show(conn, %{"feature" => feature_name}) do
    current_user = conn.assigns.current_user
    organization = Enterprise.get_organisation(current_user.current_org_id)
    feature = String.to_existing_atom(feature_name)

    case feature in FeatureFlags.available_features() do
      true ->
        enabled = FeatureFlags.enabled?(feature, organization)

        render(conn, "show.json", %{
          feature: feature,
          enabled: enabled,
          organization: organization
        })

      false ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Feature not found"})
    end
  rescue
    ArgumentError ->
      conn
      |> put_status(:bad_request)
      |> json(%{error: "Invalid feature name"})
  end

  @doc """
  Update a specific feature flag for the current organization.
  """
  swagger_path :update do
    put("/organisations/features/{feature}")
    summary("Update feature flag")
    description("Enable or disable a specific feature flag for the current organization")

    parameters do
      feature(:path, :string, "Feature name", required: true)
      body(:body, :object, "Feature flag update", required: true)
    end

    response(200, "OK", Schema.ref(:FeatureFlag))
    response(404, "Not Found", Schema.ref(:Error))
    response(401, "Unauthorized", Schema.ref(:Error))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
  end

  def update(conn, %{"feature" => feature_name, "enabled" => enabled}) do
    current_user = conn.assigns.current_user
    organization = Enterprise.get_organisation(current_user.current_org_id)
    feature = String.to_existing_atom(feature_name)

    case feature in FeatureFlags.available_features() do
      true ->
        result =
          if enabled do
            FeatureFlags.enable(feature, organization)
          else
            FeatureFlags.disable(feature, organization)
          end

        case result do
          {:ok, _} ->
            render(conn, "update.json", %{
              feature: feature,
              enabled: enabled,
              organization: organization
            })

          :ok ->
            render(conn, "update.json", %{
              feature: feature,
              enabled: enabled,
              organization: organization
            })

          {:error, reason} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: "Failed to update feature: #{inspect(reason)}"})
        end

      false ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Feature not found"})
    end
  rescue
    ArgumentError ->
      conn
      |> put_status(:bad_request)
      |> json(%{error: "Invalid feature name"})
  end

  @doc """
  Bulk update multiple feature flags for the current organization.
  """
  swagger_path :bulk_update do
    put("/organisations/features")
    summary("Bulk update feature flags")
    description("Update multiple feature flags for the current organization")

    parameters do
      body(:body, :object, "Feature flags bulk update", required: true)
    end

    response(200, "OK")
    response(401, "Unauthorized", Schema.ref(:Error))
    response(400, "Bad Request", Schema.ref(:Error))
  end

  def bulk_update(conn, %{"features" => features_map}) when is_map(features_map) do
    current_user = conn.assigns.current_user
    organization = Enterprise.get_organisation(current_user.current_org_id)

    results =
      Enum.map(features_map, fn {feature_name, enabled} ->
        try do
          feature_name
          |> String.to_existing_atom()
          |> FeatureFlags.validate_and_update_feature(enabled, organization)
        rescue
          ArgumentError ->
            {feature_name, {:error, :invalid_feature_name}}
        end
      end)

    {successful, failed} =
      Enum.split_with(results, fn {_, result} ->
        result == :ok or match?({:ok, _}, result)
      end)

    failed_map =
      Enum.into(failed, %{}, fn {feature, error_tuple} ->
        error_message =
          case error_tuple do
            {:error, :invalid_feature} -> "Feature not available"
            {:error, :invalid_feature_name} -> "Invalid feature name format"
            {:error, reason} -> "Error: #{inspect(reason)}"
            _ -> "Unknown error"
          end

        {feature, error_message}
      end)

    render(conn, "bulk_update.json", %{
      successful: Enum.map(successful, fn {feature, _} -> feature end),
      failed: failed_map,
      organization: organization
    })
  end

  def bulk_update(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Invalid request format. Expected 'features' map."})
  end
end
