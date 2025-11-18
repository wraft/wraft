defmodule WraftDoc.Workflows.AdapterSettings do
  @moduledoc """
  Context for managing adapter settings (enable/disable adapters per organization).
  """
  import Ecto.Query

  alias WraftDoc.Account.User
  alias WraftDoc.Repo
  alias WraftDoc.Workflows.AdapterSetting
  alias WraftDoc.Workflows.Adaptors.Registry

  @doc """
  Enable an adapter for an organization.
  """
  @spec enable_adapter(User.t(), String.t()) ::
          {:ok, AdapterSetting.t()} | {:error, Ecto.Changeset.t()}
  def enable_adapter(%User{current_org_id: org_id}, adapter_name) do
    case get_setting(org_id, adapter_name) do
      nil ->
        %AdapterSetting{}
        |> AdapterSetting.changeset(%{
          adapter_name: adapter_name,
          organisation_id: org_id,
          is_enabled: true
        })
        |> Repo.insert()

      setting ->
        setting
        |> AdapterSetting.changeset(%{is_enabled: true})
        |> Repo.update()
    end
  end

  @doc """
  Disable an adapter for an organization.
  """
  @spec disable_adapter(User.t(), String.t()) ::
          {:ok, AdapterSetting.t()} | {:error, Ecto.Changeset.t()}
  def disable_adapter(%User{current_org_id: org_id}, adapter_name) do
    case get_setting(org_id, adapter_name) do
      nil ->
        %AdapterSetting{}
        |> AdapterSetting.changeset(%{
          adapter_name: adapter_name,
          organisation_id: org_id,
          is_enabled: false
        })
        |> Repo.insert()

      setting ->
        setting
        |> AdapterSetting.changeset(%{is_enabled: false})
        |> Repo.update()
    end
  end

  @doc """
  Check if an adapter is enabled for an organization.
  Defaults to true if no setting exists (backward compatibility).
  """
  @spec adapter_enabled?(Ecto.UUID.t(), String.t()) :: boolean()
  def adapter_enabled?(org_id, adapter_name) do
    case get_setting(org_id, adapter_name) do
      # Default to enabled if no setting exists
      nil -> true
      setting -> setting.is_enabled
    end
  end

  @doc """
  Get all enabled adapters for an organization.
  Returns list of adapter names that are enabled.
  """
  @spec list_enabled_adapters(Ecto.UUID.t()) :: [String.t()]
  def list_enabled_adapters(org_id) do
    all_adapters = Registry.list_adaptors()

    enabled_settings =
      AdapterSetting
      |> where([a], a.organisation_id == ^org_id and a.is_enabled == true)
      |> Repo.all()

    enabled_adapter_names =
      enabled_settings
      |> Enum.map(& &1.adapter_name)
      |> MapSet.new()

    # Filter adapters: if no setting exists, default to enabled
    Enum.filter(all_adapters, fn adapter_name ->
      MapSet.member?(enabled_adapter_names, adapter_name) ||
        not has_setting?(org_id, adapter_name)
    end)
  end

  @doc """
  Get adapter setting for an organization.
  """
  @spec get_setting(Ecto.UUID.t(), String.t()) :: AdapterSetting.t() | nil
  def get_setting(org_id, adapter_name) do
    AdapterSetting
    |> where([a], a.organisation_id == ^org_id and a.adapter_name == ^adapter_name)
    |> Repo.one()
  end

  @doc """
  Get all adapter settings for an organization.
  """
  @spec list_settings(Ecto.UUID.t()) :: [AdapterSetting.t()]
  def list_settings(org_id) do
    AdapterSetting
    |> where([a], a.organisation_id == ^org_id)
    |> Repo.all()
  end

  defp has_setting?(org_id, adapter_name) do
    AdapterSetting
    |> where([a], a.organisation_id == ^org_id and a.adapter_name == ^adapter_name)
    |> Repo.exists?()
  end
end
