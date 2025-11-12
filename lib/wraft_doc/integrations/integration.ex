defmodule WraftDoc.Integrations.Integration do
  @moduledoc """
  Schema for managing integrations with external services.

  This module defines the structure and behavior for integrations,
  including validation of provider configurations and available
  categories for different types of integrations.
  """

  use WraftDoc.Schema
  alias WraftDoc.EctoType.EncryptedMapType
  alias WraftDoc.Enterprise.Organisation
  alias WraftDoc.Integrations.IntegrationConfig

  schema "integrations" do
    field(:provider, :string)
    field(:name, :string)
    field(:category, :string)
    field(:enabled, :boolean, default: false)
    field(:config, EncryptedMapType)
    field(:events, {:array, :string}, default: [])
    field(:metadata, :map, default: %{})

    belongs_to(:organisation, Organisation)

    timestamps()
  end

  @doc false
  def changeset(integration, attrs) do
    integration
    |> cast(attrs, [
      :provider,
      :name,
      :category,
      :enabled,
      :config,
      :events,
      :metadata,
      :organisation_id
    ])
    |> validate_required([:provider, :name, :category, :organisation_id])
    |> foreign_key_constraint(:organisation_id)
    |> validate_inclusion(:provider, available_providers())
    |> validate_inclusion(:category, available_categories())
    |> validate_config()
  end

  def update_config_changeset(integration, attrs) do
    integration
    |> cast(attrs, [:config])
    |> validate_config()
  end

  def available_providers do
    IntegrationConfig.list_providers()
  end

  def available_categories do
    [
      # For DocuSign
      "document_management",
      # For Slack
      "communication",
      # For Google Drive
      "file_sharing",
      # For Okta
      "authentication",
      # For Zapier
      "automation",
      # For future storage integrations
      "storage",
      # For future CRM integrations
      "crm",
      # For future payment integrations
      "payment",
      # For future analytics integrations
      "analytics"
    ]
  end

  def provider_category(provider) do
    case IntegrationConfig.get_integration_config(provider) do
      nil -> nil
      config -> config.category
    end
  end

  defp validate_config(changeset) do
    provider = get_field(changeset, :provider)
    config = get_field(changeset, :config)

    case IntegrationConfig.get_integration_config(provider) do
      nil ->
        changeset

      integration_config ->
        validate_config_with_structure(changeset, config, integration_config)
    end
  end

  defp validate_config_with_structure(changeset, nil, _integration_config) do
    add_error(changeset, :config, "configuration is required")
  end

  defp validate_config_with_structure(changeset, config, integration_config) do
    required_fields = get_required_fields(integration_config.config_structure)
    missing_fields = validate_required_fields(config, required_fields)

    case missing_fields do
      [] ->
        changeset

      errors ->
        add_error(
          changeset,
          :config,
          "missing required fields: #{Enum.join(errors, ", ")}"
        )
    end
  end

  defp get_required_fields(config_structure) do
    config_structure
    |> Enum.filter(fn {_key, field} -> field.required end)
    |> Enum.map(fn {key, _field} -> Atom.to_string(key) end)
  end

  defp validate_required_fields(config, required_fields) do
    Enum.filter(required_fields, fn field ->
      !Map.has_key?(config, field) || is_nil(config[field]) || config[field] == ""
    end)
  end
end
