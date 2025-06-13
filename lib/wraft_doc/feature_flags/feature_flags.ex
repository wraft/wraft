defmodule WraftDoc.FeatureFlags do
  @moduledoc """
  Organization-based feature flag management using FunWithFlags.

  This module provides functions to manage feature flags at the organization level,
  with all features disabled by default for all organizations.
  """

  alias WraftDoc.Enterprise.Organisation

  # Define available features
  @available_features [
    :ai_features,
    :repository,
    :document_extraction
  ]

  @doc """
  Check if a feature is enabled for a specific organization.
  Returns false by default if the feature is not explicitly enabled.
  """
  @spec enabled?(atom(), Organisation.t() | map()) :: boolean()
  def enabled?(feature, %Organisation{} = organization) when feature in @available_features do
    FunWithFlags.enabled?(feature, for: organization)
  end

  def enabled?(feature, %{id: _} = organization) when feature in @available_features do
    FunWithFlags.enabled?(feature, for: organization)
  end

  def enabled?(_, _), do: false

  @doc """
  Enable a feature for a specific organization.
  """
  @spec enable(atom(), Organisation.t() | map()) :: :ok | {:error, any()}
  def enable(feature, organization) when feature in @available_features do
    FunWithFlags.enable(feature, for_actor: organization)
  end

  def enable(_, _), do: {:error, :invalid_feature}

  @doc """
  Disable a feature for a specific organization.
  """
  @spec disable(atom(), Organisation.t() | map()) :: :ok | {:error, any()}
  def disable(feature, organization) when feature in @available_features do
    FunWithFlags.disable(feature, for_actor: organization)
  end

  def disable(_, _), do: {:error, :invalid_feature}

  @doc """
  Get all available features.
  """
  @spec available_features() :: list(atom())
  def available_features, do: @available_features

  @doc """
  Get enabled features for an organization.
  """
  @spec enabled_features(Organisation.t() | map()) :: list(atom())
  def enabled_features(organization) do
    Enum.filter(@available_features, &enabled?(&1, organization))
  end

  @doc """
  Get disabled features for an organization.
  """
  @spec disabled_features(Organisation.t() | map()) :: list(atom())
  def disabled_features(organization) do
    Enum.reject(@available_features, &enabled?(&1, organization))
  end

  @doc """
  Bulk enable multiple features for an organization.
  """
  @spec bulk_enable(list(atom()), Organisation.t() | map()) :: :ok | {:error, any()}
  def bulk_enable(features, organization) when is_list(features) do
    Enum.each(features, &enable(&1, organization))
    :ok
  rescue
    error -> {:error, error}
  end

  @doc """
  Bulk disable multiple features for an organization.
  """
  @spec bulk_disable(list(atom()), Organisation.t() | map()) :: :ok | {:error, any()}
  def bulk_disable(features, organization) when is_list(features) do
    Enum.each(features, &disable(&1, organization))
    :ok
  rescue
    error -> {:error, error}
  end

  @doc """
  Set up default feature flags for a new organization (all disabled).
  """
  @spec setup_defaults(Organisation.t() | map()) :: :ok
  def setup_defaults(organization) do
    # Ensure all features are disabled by default
    bulk_disable(@available_features, organization)
  end

  @doc """
  Get feature flag status for an organization.
  """
  @spec get_organization_features(Organisation.t() | map()) :: map()
  def get_organization_features(organization) do
    Enum.into(@available_features, %{}, fn feature ->
      {feature, enabled?(feature, organization)}
    end)
  end

  @doc """
  Enable a feature globally (for all organizations).
  This should be used carefully and only for system-wide features.
  """
  @spec enable_globally(atom()) :: :ok | {:error, any()}
  def enable_globally(feature) when feature in @available_features do
    FunWithFlags.enable(feature)
  end

  def enable_globally(_), do: {:error, :invalid_feature}

  @doc """
  Disable a feature globally.
  """
  @spec disable_globally(atom()) :: :ok | {:error, any()}
  def disable_globally(feature) when feature in @available_features do
    FunWithFlags.disable(feature)
  end

  def disable_globally(_), do: {:error, :invalid_feature}

  @doc """
  Check if a feature is enabled globally.
  """
  @spec enabled_globally?(atom()) :: boolean()
  def enabled_globally?(feature) when feature in @available_features do
    FunWithFlags.enabled?(feature)
  end

  def enabled_globally?(_), do: false
end
