defmodule WraftDocWeb.Api.V1.FeatureFlagController do
  @moduledoc """
  Controller for managing organization-based feature flags.
  """
  use WraftDocWeb, :controller
  use OpenApiSpex.ControllerSpecs

  plug WraftDocWeb.Plug.Authorized,
    index: "organisation:show",
    show: "organisation:show",
    update: "organisation:manage",
    bulk_update: "organisation:manage"

  action_fallback(WraftDocWeb.FallbackController)

  alias WraftDoc.Enterprise
  alias WraftDoc.FeatureFlags
  alias WraftDocWeb.Schemas.Error
  alias WraftDocWeb.Schemas.FeatureFlag, as: FeatureFlagSchema

  tags(["Feature Flags"])

  operation(:index,
    summary: "List organization feature flags",
    description: "Get all feature flags and their status for the current organization",
    responses: [
      ok: {"OK", "application/json", FeatureFlagSchema.FeatureFlagsList},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

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

  operation(:show,
    summary: "Get specific feature flag",
    description: "Get the status of a specific feature flag for the current organization",
    parameters: [
      feature: [in: :path, type: :string, description: "Feature name", required: true]
    ],
    responses: [
      ok: {"OK", "application/json", FeatureFlagSchema.FeatureFlag},
      not_found: {"Not Found", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

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

  operation(:update,
    summary: "Update feature flag",
    description: "Enable or disable a specific feature flag for the current organization",
    parameters: [
      feature: [in: :path, type: :string, description: "Feature name", required: true]
    ],
    request_body:
      {"Feature flag update", "application/json", FeatureFlagSchema.FeatureFlagUpdateRequest},
    responses: [
      ok: {"OK", "application/json", FeatureFlagSchema.FeatureFlag},
      not_found: {"Not Found", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error}
    ]
  )

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

  operation(:bulk_update,
    summary: "Bulk update feature flags",
    description: "Update multiple feature flags for the current organization",
    request_body:
      {"Feature flags bulk update", "application/json",
       FeatureFlagSchema.BulkFeatureFlagUpdateRequest},
    responses: [
      ok: {"OK", "application/json", FeatureFlagSchema.BulkFeatureFlagUpdateResponse},
      unauthorized: {"Unauthorized", "application/json", Error},
      bad_request: {"Bad Request", "application/json", Error}
    ]
  )

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
