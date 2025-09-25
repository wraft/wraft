defmodule WraftDoc.Integrations do
  @moduledoc """
  The Integrations context.
  """

  import Ecto.Query, warn: false
  alias WraftDoc.Account.User
  alias WraftDoc.Integrations.Integration
  alias WraftDoc.Repo

  @doc """
  Returns the list of integrations for an organization.
  """
  def list_organisation_integrations(organisation_id) do
    Integration
    |> where([i], i.organisation_id == ^organisation_id)
    |> Repo.all()
  end

  @doc """
  Gets a single integration.
  """
  def get_integration!(id), do: Repo.get!(Integration, id)

  @doc """
  Gets a single integration by provider for an organization.
  """
  def get_integration_by_provider(organisation_id, provider) do
    Integration
    |> where([i], i.organisation_id == ^organisation_id and i.provider == ^provider)
    |> Repo.one()
  end

  def update_metadata(%Integration{} = integration, metadata) when is_map(metadata) do
    integration
    |> Integration.changeset(%{metadata: metadata})
    |> Repo.update()
  end

  @doc """
  Creates an integration.
  """
  def create_integration(attrs \\ %{}) do
    attrs = maybe_add_category(attrs)

    %Integration{}
    |> Integration.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an integration.
  """
  def update_integration(%Integration{} = integration, attrs) do
    integration
    |> Integration.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes an integration.
  """
  def delete_integration(%Integration{} = integration) do
    Repo.delete(integration)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking integration changes.
  """
  def change_integration(%Integration{} = integration, attrs \\ %{}) do
    Integration.changeset(integration, attrs)
  end

  @doc """
  Enables an integration for an organization.
  """
  def enable_integration(%Integration{} = integration) do
    update_integration(integration, %{enabled: true})
  end

  @doc """
  Disables an integration for an organization.
  """
  def disable_integration(%Integration{} = integration) do
    update_integration(integration, %{enabled: false})
  end

  @doc """
  Updates integration events.
  """
  def update_integration_events(%Integration{} = integration, events) when is_list(events) do
    update_integration(integration, %{events: events})
  end

  @doc """
  Checks if an integration is enabled for an organization.
  """
  def integration_enabled?(organisation_id, provider) do
    case get_integration_by_provider(organisation_id, provider) do
      %Integration{enabled: enabled} -> enabled
      nil -> false
    end
  end

  @doc """
  Gets the configuration for an integration.
  """
  def get_integration_config(organisation_id, provider) do
    case get_integration_by_provider(organisation_id, provider) do
      %Integration{enabled: true, config: config} -> {:ok, config}
      %Integration{enabled: false} -> {:error, :integration_disabled}
      nil -> {:error, :integration_not_found}
    end
  end

  @spec get_latest_token(User.t(), atom()) :: String.t() | nil
  def get_latest_token(%User{current_org_id: org_id}, type) do
    case Integration
         |> where([i], i.provider == ^type and i.organisation_id == ^org_id)
         |> order_by([i], desc: i.inserted_at)
         |> limit(1)
         |> Repo.one() do
      nil ->
        {:error, "No integration found for #{type}"}

      %Integration{metadata: nil} ->
        {:error, "Integration found but no tokens available"}

      %Integration{metadata: metadata} ->
        case metadata do
          %{"access_token" => token} -> token
          _ -> {:error, "No access token found"}
        end
    end
  end

  @doc """
  Returns all available categories.
  """
  def available_categories do
    Integration.available_categories()
  end

  @doc """
  Returns all providers for a specific category.
  """
  def providers_by_category(category) do
    Enum.filter(Integration.available_providers(), fn provider ->
      Integration.provider_category(provider) == category
    end)
  end

  # Private functions

  defp maybe_add_category(%{"provider" => provider} = attrs) do
    if Map.has_key?(attrs, "category") do
      attrs
    else
      Map.put(attrs, "category", Integration.provider_category(provider))
    end
  end

  defp maybe_add_category(attrs), do: attrs
end
